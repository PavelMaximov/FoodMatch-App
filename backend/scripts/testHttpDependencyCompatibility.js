// Local HTTP checks: no database, auth provider or image hosting calls.
require('ts-node/register');
const assert = require('node:assert/strict');
const express = require('express');
const morgan = require('morgan');
const { imageUpload, mapMulterError, requireUploadedImage } = require('../src/modules/uploads/middleware/uploadMiddleware');

async function main() {
  const app = express();
  const logs = [];
  app.use(morgan(':remote-user :method :url', { stream: { write: line => logs.push(line) } }));
  app.use(express.json({ limit: '200kb' }));
  app.use(express.urlencoded({ extended: false, limit: '50kb' }));
  app.post('/echo', (req, res) => res.json(req.body));
  app.post('/upload', imageUpload.single('file'), (req, res) => {
    const file = requireUploadedImage(req.file);
    res.json({ size: file.size, name: file.originalname });
  });
  app.use((error, _req, res, _next) => {
    const mapped = mapMulterError(error);
    res.status(mapped.statusCode || mapped.status || 400).json({ code: mapped.code });
  });
  const server = app.listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  const url = `http://127.0.0.1:${server.address().port}`;
  async function upload(name, type, size) {
    const form = new FormData();
    form.append('file', new Blob([new Uint8Array(size)], { type }), name);
    return fetch(`${url}/upload`, { method: 'POST', body: form });
  }
  try {
    let response = await fetch(`${url}/echo`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ name: 'dish' }) });
    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), { name: 'dish' });
    response = await fetch(`${url}/echo`, { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body: 'name=Soup&tag=a&tag=b' });
    assert.deepEqual(await response.json(), { name: 'Soup', tag: ['a', 'b'] });
    response = await fetch(`${url}/echo`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ value: 'x'.repeat(201 * 1024) }) });
    assert.equal(response.status, 413);
    for (const [name, type] of [['dish.jpg', 'image/jpeg'], ['dish.png', 'image/png'], ['dish.webp', 'image/webp']]) {
      response = await upload(name, type, 16);
      assert.equal(response.status, 200);
      assert.deepEqual(await response.json(), { size: 16, name });
    }
    response = await upload('dish.txt', 'text/plain', 16);
    assert.equal(response.status, 400);
    assert.equal((await response.json()).code, 'INVALID_IMAGE_TYPE');
    response = await upload('large.png', 'image/png', 5 * 1024 * 1024 + 1);
    assert.equal(response.status, 413);
    assert.equal((await response.json()).code, 'IMAGE_TOO_LARGE');
    await fetch(`${url}/echo`, { method: 'POST', headers: { Authorization: `Basic ${Buffer.from('user\u2028forged:password').toString('base64')}`, 'Content-Type': 'application/json' }, body: '{}' });
    assert(logs.length >= 9);
    assert(logs.every(line => !line.includes('\u2028') && !line.includes('\r') && !line.slice(0, -1).includes('\n')));
    console.log('PASS HTTP dependency compatibility: body parsing, size limits, image filtering and log escaping');
  } finally {
    server.closeAllConnections();
    await new Promise(resolve => server.close(resolve));
  }
}
main().catch(error => { console.error(error); process.exitCode = 1; });
