import { picker, fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { common } from '@kit.AbilityKit';
import { ClientError, validateSignaturePNG } from '../core/Models';
import type { Payload } from '../core/Models';

// Picker授予本次文件读取能力；不申请全盘访问，也不留存原件副本。
export async function chooseEvidence(context: common.UIAbilityContext): Promise<Payload> {
  const view = new picker.DocumentViewPicker(context);
  const uris = await view.select({ maxSelectNumber: 1 });
  if (uris.length === 0) {
    throw new ClientError('已取消选择文件。');
  }
  const uri = uris[0];
  const name = decodeURIComponent(uri.split('/').pop() || '归档原件');
  const extension = name.split('.').pop()?.toLowerCase() || '';
  const types: Record<string, string> = {
    png: 'image/png', jpg: 'image/jpeg', jpeg: 'image/jpeg', gif: 'image/gif',
    pdf: 'application/pdf', txt: 'text/plain', mp3: 'audio/mpeg', wav: 'audio/wav',
    ogg: 'audio/ogg', mp4: 'video/mp4'
  };
  const mime = types[extension];
  if (!mime) {
    throw new ClientError('请选择 PNG/JPG/GIF/PDF/TXT/MP3/WAV/OGG/MP4 原件。');
  }
  const file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
  try {
    const size = fs.statSync(file.fd).size;
    if (size <= 0 || size > 1024 * 1024) {
      throw new ClientError('原生移动端单份原件须大于0且不超过1MB。');
    }
    const buffer = new ArrayBuffer(size);
    const read = fs.readSync(file.fd, buffer);
    if (read !== size) {
      throw new ClientError('未完整读取文件，请重新选择。');
    }
    const kind = mime.indexOf('image/') === 0 ? 'image' : mime.indexOf('audio/') === 0 ? 'audio' : mime.indexOf('video/') === 0 ? 'video' : 'document';
    return { name: name, kind: kind, mime: mime, data: new util.Base64Helper().encodeToStringSync(new Uint8Array(buffer)) };
  } finally {
    fs.closeSync(file.fd);
  }
}

export function checkedSignature(dataURL: string): string {
  const prefix = 'data:image/png;base64,';
  if (dataURL.indexOf(prefix) !== 0) {
    throw new ClientError('签署画布未导出 PNG 图像。');
  }
  validateSignaturePNG(new util.Base64Helper().decodeSync(dataURL.slice(prefix.length)));
  return dataURL;
}
