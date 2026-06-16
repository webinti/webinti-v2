'use strict';
/**
 * Cadrage Quai Sud — réception du formulaire de cadrage et envoi par email.
 * Service HTTP local, proxifié par nginx sur https://webinti.com/api/cadrage.
 * Envoie le mail via Postfix (sendmail) — aucune dépendance npm.
 */
const http = require('http');
const { spawn } = require('child_process');

const PORT      = 3201;
const HOST      = '127.0.0.1';
const MAIL_TO   = 'agence.webinti@gmail.com';
const MAIL_FROM = 'Webinti Cadrage <cadrage@webinti.com>';
const SENDMAIL  = '/usr/sbin/sendmail';
const MAX_BODY  = 256 * 1024; // 256 Ko

const EMAIL_RE = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

function encodeHeader(value) {
  // RFC 2047 — encode l'en-tête si caractères non-ASCII
  if (/^[\x20-\x7E]*$/.test(value)) return value;
  return '=?UTF-8?B?' + Buffer.from(value, 'utf8').toString('base64') + '?=';
}

function sendMail({ subject, replyTo, body }) {
  return new Promise((resolve, reject) => {
    const headers = [
      'From: ' + MAIL_FROM,
      'To: ' + MAIL_TO,
    ];
    if (replyTo) headers.push('Reply-To: ' + replyTo);
    headers.push('Subject: ' + encodeHeader(subject));
    headers.push('MIME-Version: 1.0');
    headers.push('Content-Type: text/plain; charset=UTF-8');
    headers.push('Content-Transfer-Encoding: 8bit');

    const message = headers.join('\r\n') + '\r\n\r\n' + body;

    const child = spawn(SENDMAIL, ['-t', '-i'], { stdio: ['pipe', 'ignore', 'pipe'] });
    let stderr = '';
    child.stderr.on('data', d => { stderr += d; });
    child.on('error', reject);
    child.on('close', code => {
      if (code === 0) resolve();
      else reject(new Error('sendmail a renvoyé le code ' + code + ' — ' + stderr));
    });
    child.stdin.write(message, 'utf8');
    child.stdin.end();
  });
}

function buildBody(data) {
  const company = (data.company || 'Société inconnue').toString();
  const email   = (data.email || '—').toString();
  const when    = (data._submitted_at || new Date().toISOString()).toString();
  const summary = (data._summary || '(résumé non transmis)').toString();

  return [
    'Nouveau questionnaire de cadrage reçu.',
    '',
    'Société   : ' + company,
    'Email     : ' + email,
    'Reçu le   : ' + when,
    'Source    : ' + (data._source || '—'),
    '',
    '──────────────────────────────────────────',
    '  RÉPONSES',
    '──────────────────────────────────────────',
    summary,
    '',
    '──────────────────────────────────────────',
    '  DONNÉES BRUTES (JSON)',
    '──────────────────────────────────────────',
    JSON.stringify(data, null, 2),
    '',
  ].join('\n');
}

const server = http.createServer((req, res) => {
  const json = (status, obj) => {
    res.writeHead(status, {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
    });
    res.end(JSON.stringify(obj));
  };

  if (req.method === 'GET' && req.url === '/api/cadrage/health') {
    return json(200, { ok: true });
  }

  if (req.method !== 'POST' || req.url !== '/api/cadrage') {
    return json(404, { ok: false, error: 'not_found' });
  }

  let body = '';
  let aborted = false;
  req.on('data', chunk => {
    body += chunk;
    if (body.length > MAX_BODY) {
      aborted = true;
      json(413, { ok: false, error: 'payload_too_large' });
      req.destroy();
    }
  });
  req.on('end', async () => {
    if (aborted) return;
    let data;
    try {
      data = JSON.parse(body);
    } catch {
      return json(400, { ok: false, error: 'invalid_json' });
    }

    const company  = (data.company || '').toString().slice(0, 200).trim() || 'Société inconnue';
    const rawEmail = (data.email || '').toString().trim();
    const replyTo  = EMAIL_RE.test(rawEmail) ? rawEmail : null;

    try {
      await sendMail({
        subject: 'Cadrage Quai Sud — ' + company,
        replyTo,
        body: buildBody(data),
      });
      console.log(new Date().toISOString(), 'OK', company);
      json(200, { ok: true });
    } catch (err) {
      console.error(new Date().toISOString(), 'ERREUR', err.message);
      json(502, { ok: false, error: 'mail_failed' });
    }
  });
  req.on('error', () => {
    if (!aborted) json(400, { ok: false, error: 'request_error' });
  });
});

server.listen(PORT, HOST, () => {
  console.log('cadrage-service à l\'écoute sur http://' + HOST + ':' + PORT);
});
