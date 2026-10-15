const OperationsData = (() => {
  const text = value => typeof value === "string";
  const integer = value => Number.isSafeInteger(value);
  const amount = value => integer(value) && value >= 0;
  const strings = value => Array.isArray(value) && value.every(text);
  const application = value => value && text(value.id) && /^[A-Za-z0-9_-]{1,80}$/.test(value.id) && text(value.workerId) &&
    text(value.displayName) && text(value.contactPhone) && strings(value.serviceAreas) &&
    strings(value.skills) && strings(value.assetIds) && text(value.bio) &&
    ["pending", "approved", "rejected"].includes(value.status) && integer(value.revision);
  const journal = value => value && text(value.id) && text(value.orderId) && text(value.customerId) &&
    text(value.workerId) && ["collection", "manual_payout", "reversal"].includes(value.kind) &&
    ["simulated", "actual"].includes(value.mode) && typeof value.simulated === "boolean" &&
    (value.mode === "simulated") === value.simulated && text(value.channel) &&
    ["posted", "reversed"].includes(value.status) && amount(value.amountCents) &&
    amount(value.workerShareCents) && amount(value.platformFeeCents) && text(value.occurredAt) &&
    Array.isArray(value.entries) && value.entries.length >= 2 && value.entries.every(entry => entry && text(entry.account) &&
      ["debit", "credit"].includes(entry.direction) && amount(entry.amountCents)) &&
    value.entries.reduce((sum, entry) => sum + (entry.direction === "debit" ? entry.amountCents : -entry.amountCents), 0) === 0;
  const summaryFields = ["collectedCents", "platformRevenueCents", "workerAccruedCents", "payoutCents",
    "platformFundsCents", "workerPayableCents", "journalCount"];
  return {
    applications: value => Array.isArray(value) && value.every(application),
    journals: value => Array.isArray(value) && value.every(journal),
    summary: value => value && ["simulated", "actual"].includes(value.mode) &&
      (value.mode === "simulated") === value.simulated && value.currency === "CNY" && value.scope === "filtered_movements" &&
      summaryFields.every(field => integer(value[field])),
    emptySummary: (mode = "simulated") => Object.fromEntries([...summaryFields.map(field => [field, 0]),
      ["mode", mode], ["simulated", mode === "simulated"], ["currency", "CNY"], ["scope", "filtered_movements"]])
  };
})();
