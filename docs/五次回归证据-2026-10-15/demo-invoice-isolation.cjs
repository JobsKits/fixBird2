/* Jobs · 仅隔离发票守卫，显式PDF测试fixture；不修改产品或原24项诊断。 */
const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");
const assert = require("node:assert/strict");
const root = "/Users/jobs/Desktop/啄木鸟维修平台-V3.8";
const D = require(path.join(root, "Workspace/data.js"));
const originalScript = fs.readFileSync(path.join(__dirname, "demo-sequences.cjs"), "utf8");
const setupEnd = originalScript.indexOf('\nfor (const mode of ["consume"');
assert.ok(setupEnd > 0, "original diagnostic setup boundary changed");
const { demo, action, state, order } = new Function(
  "require", originalScript.slice(0, setupEnd) + "\nreturn {demo, action, state, order};",
)(require);

function syntheticPDF() {
  const stream = "BT /F1 12 Tf 20 45 Td (SYNTHETIC INVOICE TEST ONLY) Tj ET\n";
  const objects = [
    "<< /Type /Catalog /Pages 2 0 R >>",
    "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 320 100] /Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>",
    "<< /Length " + Buffer.byteLength(stream) + " >>\nstream\n" + stream + "endstream",
    "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
  ];
  let pdf = "%PDF-1.4\n% SYNTHETIC TEST DOCUMENT\n";
  const offsets = [0];
  objects.forEach((object, index) => {
    offsets.push(Buffer.byteLength(pdf));
    pdf += index + 1 + " 0 obj\n" + object + "\nendobj\n";
  });
  const xref = Buffer.byteLength(pdf);
  pdf += "xref\n0 6\n0000000000 65535 f \n";
  for (const offset of offsets.slice(1)) pdf += String(offset).padStart(10, "0") + " 00000 n \n";
  pdf += "trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n" + xref + "\n%%EOF\n";
  for (const [index, offset] of offsets.slice(1).entries()) {
    assert.ok(pdf.slice(offset).startsWith(index + 1 + " 0 obj\n"));
  }
  assert.ok(pdf.slice(xref).startsWith("xref\n"));
  return Buffer.from(pdf, "ascii");
}

const pdf = syntheticPDF();
const evidence = {
  id: "isolated-current-valid-pdf",
  name: "synthetic-isolated-invoice.pdf",
  kind: "document",
  mime: "application/pdf",
  data: pdf.toString("base64"),
  text: "",
  deleted: false,
  public: true,
  uploaderId: "finance",
  createdAt: "2026-10-15T08:00:00Z",
  stage: "settling",
  sha256: crypto.createHash("sha256").update(pdf).digest("hex"),
};
async function prepared() {
  const h = await demo("finance");
  // Binary upload is intentionally unavailable in independent demo. This is an
  // explicit boundary fixture, not a claim that the UI uploaded an actual file.
  const source = h.app.getDemo().orders.find((o) => o.id === "demo-002");
  source.evidence = [structuredClone(evidence)];
  source.invoices = [];
  source.invoiceRequirement = "required";
  source.invoiceDueCents = 10000;
  source.summary = D.derive(source, h.app.getDemo().loans);
  h.app.openDemo("finance");
  const actual = order(h, source.id).evidence[0];
  assert.equal(actual.kind, "document");
  assert.equal(actual.mime, "application/pdf");
  assert.equal(actual.deleted, false);
  assert.ok(Buffer.from(actual.data, "base64").equals(pdf));
  return h;
}

const rows = [], observations = {};
const checks = [
  ["I01", "合法PDF与唯一票号的实际发票callback可以保存（正对照）", async () => {
    const h = await prepared();
    await action(h, "invoice", "demo-002", { number: "ISOLATED-UNIQUE", amountCents: "100.00", files: [evidence.id] });
    const current = order(h, "demo-002");
    assert.equal(current.invoices.length, 1);
    assert.equal(current.invoices[0].number, "ISOLATED-UNIQUE");
    assert.deepEqual(Array.from(current.invoices[0].files), [evidence.id]);
    observations.I01 = { invoices: current.invoices, evidenceKind: current.evidence[0].kind, evidenceMIME: current.evidence[0].mime, validCurrentPDF: true };
  }],
  ["I02", "同一合法PDF下重复有效票号仍须拒绝，排除文字附件混杂", async () => {
    const h = await prepared();
    const fields = { number: "ISOLATED-DUPLICATE", amountCents: "100.00", files: [evidence.id] };
    await action(h, "invoice", "demo-002", fields);
    assert.equal(order(h, "demo-002").invoices.length, 1, "合法初次登记应先成功");
    const before = JSON.stringify(state(h));
    await action(h, "invoice", "demo-002", fields);
    observations.I02 = { invoices: order(h, "demo-002").invoices, error: h.node("#formError").textContent, validCurrentPDF: true };
    assert.equal(JSON.stringify(state(h)), before, "合法PDF不变时，重复有效票号仍被作为第二张发票保存");
  }],
  ["I03", "none约定下合法PDF仍不得登记新票，排除文字附件混杂", async () => {
    const h = await prepared();
    await action(h, "requirements", "demo-002", { documentRequirement: "none", documentReason: "合成无需资料", invoiceRequirement: "none", invoiceReason: "合成无需票据", invoiceDueCents: "0.00" });
    assert.equal(order(h, "demo-002").invoiceRequirement, "none");
    assert.equal(order(h, "demo-002").invoices.length, 0);
    const before = JSON.stringify(state(h));
    await action(h, "invoice", "demo-002", { number: "ISOLATED-NONE-REQUIREMENT", amountCents: "100.00", files: [evidence.id] });
    observations.I03 = { requirement: order(h, "demo-002").invoiceRequirement, invoices: order(h, "demo-002").invoices, error: h.node("#formError").textContent, validCurrentPDF: true };
    assert.equal(JSON.stringify(state(h)), before, "即使PDF原件合法，none约定下仍被登记新票");
  }],
];
(async () => {
  for (const [index, [id, title, fn]] of checks.entries()) {
    try {
      await fn(); rows.push({ id, title, passed: true });
      console.log("ok " + (index + 1) + " - " + id + " " + title);
    } catch (error) {
      rows.push({ id, title, passed: false, message: error.message, stack: error.stack });
      console.log("not ok " + (index + 1) + " - " + id + " " + title + "\n  " + error.message.split("\n")[0]);
    }
  }
  const source = Object.fromEntries(["Workspace/data.js", "Workspace/app.js", "Workspace/tests/app.test.cjs"].map((file) => [file, crypto.createHash("sha256").update(fs.readFileSync(path.join(root, file))).digest("hex")]));
  const report = { date: "2026-10-15", tests: rows.length, pass: rows.filter((r) => r.passed).length, fail: rows.filter((r) => !r.passed).length, skip: 0, source, evidence, observations, rows,
    fixture: "Explicit one-page valid PDF boundary fixture in VM demo memory: current nondeleted document/application/pdf with base64 original and cross-reference offsets. Existing seed text references/invoices are replaced only in this isolated test memory. Actual invoice and requirement form callbacks then run unchanged.",
    limit: "No binary upload flow claimed: independent demo intentionally does not persist real binary uploads. The fixture matches actual Go checkFiles/invoiceFiles PDF metadata/original requirements. Not a real tax invoice or real-service test.",
    cleanup: "Node-only VM state; no services, browsers, temp dirs, credentials or product writes." };
  const output = process.argv[2] || "demo-invoice-isolation.json";
  assert.match(output, /^demo-invoice-isolation(?:-repeat)?\.json$/);
  fs.writeFileSync(path.join(__dirname, output), JSON.stringify(report, null, 2) + "\n");
  console.log(JSON.stringify({ tests: report.tests, pass: report.pass, fail: report.fail, skip: 0 }));
  process.exitCode = report.fail ? 1 : 0;
})().catch((error) => { console.error(error); process.exitCode = 2; });
