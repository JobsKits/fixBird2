import { http } from '@kit.NetworkKit';
import { ClientError } from '../core/Models';
import type { Transport } from '../core/WorkbenchStore';

class ErrorResponse {
  message: string = '';
  error: string = '';
}

export class HttpTransport implements Transport {
  async send(base: string, path: string, method: string, body: string, token: string, key: string, timeout: number): Promise<string> {
    const task = http.createHttp();
    const headers: Record<string, string> = { 'Accept': 'application/json', 'Content-Type': 'application/json' };
    if (token) {
      headers['Authorization'] = 'Bearer ' + token;
    }
    if (key) {
      headers['Idempotency-Key'] = key;
    }
    try {
      const response = await task.request(base + (path === '/healthz' ? path : '/api/v38' + path), {
        method: method === 'POST' ? http.RequestMethod.POST : http.RequestMethod.GET,
        header: headers,
        extraData: body,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: timeout,
        readTimeout: timeout,
        usingCache: false
      });
      if (response.responseCode < 200 || response.responseCode >= 300) {
        let message = '服务器返回 ' + response.responseCode;
        try {
          const result = JSON.parse(response.result as string) as ErrorResponse;
          message = result.message || message;
        } catch (_) {}
        throw new ClientError(message, response.responseCode, response.responseCode >= 500);
      }
      if (typeof response.result !== 'string') {
        throw new ClientError('服务器未返回有效 JSON 文本。', 0, method === 'POST');
      }
      return response.result as string;
    } finally {
      task.destroy();
    }
  }
}
