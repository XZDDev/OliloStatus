#!/usr/bin/env node
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Aydan Abrahams

// Small ops CLI for the notifications backend. Talks straight to the database,
// so it works without the server running. Usage:
//   node src/cli.js <command>     (or: npm run cli -- <command>)

import { pool, query } from './db/pool.js';

const [cmd, ...args] = process.argv.slice(2);
const hasFlag = (f) => args.includes(f);

function maskToken(t) {
  if (!t || t.length <= 16) return t;
  return `${t.slice(0, 8)}...${t.slice(-6)}`;
}

function ago(ts) {
  if (!ts) return '-';
  const s = Math.floor((Date.now() - new Date(ts).getTime()) / 1000);
  if (s < 60) return `${s}s`;
  if (s < 3600) return `${Math.floor(s / 60)}m`;
  if (s < 86400) return `${Math.floor(s / 3600)}h`;
  return `${Math.floor(s / 86400)}d`;
}

function prefsSummary(p = {}) {
  const on = ['incidents', 'maintenance', 'componentAlerts'].filter((k) => p[k]).map((k) => k[0].toUpperCase());
  const nets = (p.networks || []).length ? ` [${p.networks.join(',')}]` : '';
  return (on.join('') || '-') + nets;
}

// Print rows as an aligned table.
function table(headers, rows) {
  if (!rows.length) {
    console.log('(none)');
    return;
  }
  const widths = headers.map((h, i) => Math.max(h.length, ...rows.map((r) => String(r[i] ?? '').length)));
  const line = (cells) => cells.map((c, i) => String(c ?? '').padEnd(widths[i])).join('  ');
  console.log(line(headers));
  console.log(widths.map((w) => '-'.repeat(w)).join('  '));
  for (const r of rows) console.log(line(r));
}

async function listDevices() {
  const all = hasFlag('--all');
  const { rows } = await query(
    `SELECT id, token, platform, preferences, active, last_seen_at, app_version
       FROM devices ${all ? '' : 'WHERE active = TRUE'}
       ORDER BY last_seen_at DESC`,
  );
  if (hasFlag('--json')) {
    console.log(JSON.stringify(rows, null, 2));
    return;
  }
  table(
    ['ID', 'PLATFORM', 'TOKEN', 'PREFS', 'VER', 'ACTIVE', 'SEEN'],
    rows.map((r) => [
      r.id,
      r.platform,
      maskToken(r.token),
      prefsSummary(r.preferences),
      r.app_version || '-',
      r.active ? 'yes' : 'no',
      ago(r.last_seen_at),
    ]),
  );
  console.log(`\n${rows.length} device(s)${all ? '' : ' (active; use --all to include inactive)'}`);
}

async function stats() {
  const { rows } = await query(
    `SELECT
       count(*) FILTER (WHERE active)::int                                    AS active,
       count(*) FILTER (WHERE NOT active)::int                                AS inactive,
       count(*) FILTER (WHERE active AND platform = 'ios')::int               AS ios,
       count(*) FILTER (WHERE active AND platform = 'android')::int           AS android,
       count(*) FILTER (WHERE active AND (preferences->>'incidents')::boolean)::int       AS incidents,
       count(*) FILTER (WHERE active AND (preferences->>'maintenance')::boolean)::int     AS maintenance,
       count(*) FILTER (WHERE active AND (preferences->>'componentAlerts')::boolean)::int AS component_alerts
     FROM devices`,
  );
  const s = rows[0];
  console.log(`Active devices:    ${s.active}  (iOS ${s.ios}, Android ${s.android})`);
  console.log(`Inactive devices:  ${s.inactive}`);
  console.log(`Opted in -> incidents ${s.incidents}, maintenance ${s.maintenance}, component alerts ${s.component_alerts}`);
}

async function state() {
  const inc = await query(
    `SELECT kind, name, status, impact FROM incidents WHERE NOT resolved ORDER BY kind, updated_at DESC`,
  );
  console.log('Active incidents & maintenance:');
  if (!inc.rows.length) console.log('  (none)');
  else for (const i of inc.rows) console.log(`  [${i.kind}] ${i.status} - ${i.name}${i.impact ? ` (${i.impact})` : ''}`);

  const comp = await query(`SELECT status, count(*)::int AS n FROM components GROUP BY status ORDER BY n DESC`);
  console.log('\nComponents by status:');
  if (!comp.rows.length) console.log('  (none - run a poll)');
  else for (const c of comp.rows) console.log(`  ${c.status.padEnd(20)} ${c.n}`);
}

async function poll() {
  const { pollOnce } = await import('./services/poller.js');
  console.log('Polling...');
  await pollOnce();
  console.log('Poll complete.');
}

async function remove() {
  const token = args.find((a) => !a.startsWith('--'));
  if (!token) throw new Error('usage: remove <token>');
  const { rowCount } = await query('DELETE FROM devices WHERE token = $1', [token]);
  console.log(rowCount ? `Removed ${rowCount} device(s).` : 'No device with that token.');
}

async function test() {
  const positional = args.filter((a) => !a.startsWith('--'));
  const token = positional[0];
  const message = positional.slice(1).join(' ') || 'Test notification from Olilo Status';
  if (!token) throw new Error('usage: test <token> [message]');

  const { rows } = await query('SELECT platform FROM devices WHERE token = $1', [token]);
  if (!rows.length) throw new Error('no device with that token');
  const platform = rows[0].platform;

  const { apns } = await import('./push/apns.js');
  const { fcm } = await import('./push/fcm.js');
  const provider = platform === 'ios' ? apns : fcm;
  if (!provider.enabled) throw new Error(`${platform} provider is not enabled`);

  const r = await provider.send(token, { title: 'Olilo Status', body: message, data: { type: 'test' } });
  if (r.ok) console.log('Sent.');
  else console.log(`Failed: ${r.reason || r.status}${r.invalid ? ' (token invalid - would be pruned)' : ''}`);
  apns.close?.();
}

function help() {
  console.log(`Olilo Status notifications - ops CLI

Usage: node src/cli.js <command>   (or: npm run cli -- <command>)

Commands:
  devices [--all] [--json]   List registered devices (active only by default)
  stats                      Device counts and preference breakdown
  state                      Active incidents/maintenance and component health
  poll                       Fetch the status page now and dispatch notifications
  remove <token>             Delete a device by token
  test <token> [message]     Send a test push to one device
  help                       Show this help
`);
}

const commands = { devices: listDevices, stats, state, poll, remove, test, help };

(async () => {
  const fn = commands[cmd] || help;
  await fn();
})()
  .then(() => pool.end())
  .then(() => process.exit(0))
  .catch(async (err) => {
    console.error(`error: ${err.message}`);
    await pool.end().catch(() => {});
    process.exit(1);
  });
