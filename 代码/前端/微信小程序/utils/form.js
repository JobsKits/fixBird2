// Jobs · 契约表单转换，金额始终以十进制整数分提交。
const C = require('../assets/contract.json');
function fields(definitions, order, actor) {
  return definitions.map(source => {
    const field=JSON.parse(JSON.stringify(source));
    if (field.type==='datetime') field.value=new Date(Date.now()+86400000).toISOString();
    if (field.key==='quoteVersion' && order) field.value=order.quote.version;
    if (field.key==='customerId' && actor && actor.role==='customer')field.value=actor.id;
    if (field.key==='companyId' && actor)field.value=actor.companyId;
    if (field.type==='money')field.value=(Number(field.value||0)/100).toFixed(2);
    field.index=(field.options||[]).findIndex(o=>o.value===field.value);
    return field;
  });
}
function payload(values) {
  const result={};
  for (const field of values) {
    let value=field.value;
    if(field.required && (value === '' || value === null || value === undefined))throw Error('请填写'+field.label);
    if(field.type==='money') {
      if(!/^\d+(\.\d{1,2})?$/.test(String(value)))throw Error(field.label+'请填写非负金额，最多两位小数。');
      const [whole,fraction='']=String(value).split('.');value=Number(whole)*100+Number(fraction.padEnd(2,'0'));
      if(!Number.isSafeInteger(value))throw Error('金额超出范围。');
    } else if(field.type==='int') {
      if(!/^\d+$/.test(String(value)) || !Number.isSafeInteger(Number(value)))throw Error(field.label+'请填写非负整数。');
      value=Number(value);
    } else if(field.type==='datetime') {
      if(!/T.*(Z|[+-]\d\d:\d\d)$/.test(String(value)) || !Number.isFinite(Date.parse(value)))throw Error(field.label+'需要包含时区的日期时间。');
    } else if(field.type==='list') value=String(value||'').split(',').map(v=>v.trim()).filter(Boolean);
    else if(field.type==='bool')value=!!value;
    result[field.key]=value;
  }
  return result;
}
function action(type) { return C.actions.find(v=>v.type===type); }
module.exports={fields,payload,action};
