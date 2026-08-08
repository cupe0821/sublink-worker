let callbackCounter=0;
function cbName(p){return `${p}_${Date.now()}_${callbackCounter++}`}
export function exec(command,options={}){return new Promise((resolve,reject)=>{const n=cbName('exec');window[n]=(errno,stdout,stderr)=>{resolve({errno,stdout,stderr});delete window[n]};try{ksu.exec(command,JSON.stringify(options),n)}catch(e){delete window[n];reject(e)}})}
export function toast(message){try{ksu.toast(message)}catch(_){}}
export function getPackagesInfo(packages){try{return JSON.parse(ksu.getPackagesInfo(JSON.stringify(packages)))}catch(_){return []}}
