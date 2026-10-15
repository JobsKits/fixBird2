const fs=require('node:fs');
const path=require('node:path');
const base='http://127.0.0.1:18060/api/v38';
async function main(){
  const status=process.argv[2]==='active'?'active':'disabled';
  const login=await fetch(base+'/login',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({username:'admin',password:'Demo-Repair-2026!'})});
  if(!login.ok)throw Error('合成管理员登录失败');
  const session=await login.json();
  const response=await fetch(base+'/accounts/customer/status',{method:'POST',headers:{'Content-Type':'application/json',Authorization:'Bearer '+session.token,'Idempotency-Key':'r4-browser-'+status+'-customer'},body:JSON.stringify({status,reason:'独立回归：验证会话撤销后页面清理及恢复合成账号'})});
  const account=await response.json();
  if(response.status!==200||account.status!==status)throw Error('合成客户状态设置失败');
  const logout=await fetch(base+'/logout',{method:'POST',headers:{Authorization:'Bearer '+session.token}});
  const result={syntheticOnly:true,accountId:account.id,status:account.status,authVersion:account.authVersion,revokeStatus:response.status,adminLogoutStatus:logout.status};
  fs.writeFileSync(path.join(__dirname,status==='disabled'?'browser-revocation-api.json':'browser-reactivate-api.json'),JSON.stringify(result,null,2));
  console.log(JSON.stringify(result));
}
main().catch(error=>{console.error(error.message);process.exitCode=1;});
