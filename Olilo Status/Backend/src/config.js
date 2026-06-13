// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Aydan Abrahams

import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import 'dotenv/config';

function bool(value, fallback = false) {
  if (value === undefined || value === '') return fallback;
  return ['1', 'true', 'yes', 'on'].includes(String(value).toLowerCase());
}

function int(value, fallback) {
  const n = Number.parseInt(value, 10);
  return Number.isFinite(n) ? n : fallback;
}

// Read a secret either from an inline env var (preferred for container
// platforms) or from a file path. Returns undefined when neither is set.
function readSecret(inline, path) {
  if (inline && inline.trim()) return inline;
  if (path && path.trim()) {
    return readFileSync(resolve(process.cwd(), path.trim()), 'utf8');
  }
  return undefined;
}

const apnsEnabled = bool(process.env.APNS_ENABLED, true);
const fcmEnabled = bool(process.env.FCM_ENABLED, true);
const port = int(process.env.PORT, 3000);

export const config = {
  port,
  apiKey: process.env.API_KEY?.trim() || null,

  database: {
    url: process.env.DATABASE_URL,
    ssl: process.env.DATABASE_SSL?.trim() === 'require' ? { rejectUnauthorized: false } : false,
  },

  status: {
    baseUrl: (process.env.STATUS_BASE_URL || 'https://status.olilo.co.uk').replace(/\/$/, ''),
    pollIntervalMs: int(process.env.POLL_INTERVAL_SECONDS, 60) * 1000,
  },

  apns: {
    enabled: apnsEnabled,
    key: apnsEnabled ? readSecret(process.env.APNS_KEY, process.env.APNS_KEY_PATH) : undefined,
    keyId: process.env.APNS_KEY_ID,
    teamId: process.env.APNS_TEAM_ID,
    bundleId: process.env.APNS_BUNDLE_ID,
    production: bool(process.env.APNS_PRODUCTION, false),
  },

  fcm: {
    enabled: fcmEnabled,
    serviceAccount: fcmEnabled
      ? readSecret(process.env.FCM_SERVICE_ACCOUNT, process.env.FCM_SERVICE_ACCOUNT_PATH)
      : undefined,
  },
};

export function assertConfig() {
  const errors = [];
  if (!config.database.url) errors.push('DATABASE_URL is required');

  if (config.apns.enabled) {
    if (!config.apns.key) errors.push('APNS_KEY or APNS_KEY_PATH is required when APNS_ENABLED');
    if (!config.apns.keyId) errors.push('APNS_KEY_ID is required when APNS_ENABLED');
    if (!config.apns.teamId) errors.push('APNS_TEAM_ID is required when APNS_ENABLED');
    if (!config.apns.bundleId) errors.push('APNS_BUNDLE_ID is required when APNS_ENABLED');
  }
  if (config.fcm.enabled && !config.fcm.serviceAccount) {
    errors.push('FCM_SERVICE_ACCOUNT or FCM_SERVICE_ACCOUNT_PATH is required when FCM_ENABLED');
  }
  if (!config.apns.enabled && !config.fcm.enabled) {
    errors.push('At least one of APNS_ENABLED or FCM_ENABLED must be true');
  }

  if (errors.length) {
    throw new Error('Invalid configuration:\n  - ' + errors.join('\n  - '));
  }
}
