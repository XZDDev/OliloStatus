// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Aydan Abrahams

import { createHash } from 'node:crypto';
import { config } from '../config.js';
import { logger } from '../logger.js';
import { fetchSummary, fetchComponents } from './statusClient.js';
import { notify } from './notifier.js';
import * as incidentsRepo from '../repositories/incidents.js';
import * as componentsRepo from '../repositories/components.js';

// Component statuses the upstream reports as healthy - no alert when at these.
const OPERATIONAL = new Set(['OPERATIONAL', 'UP', 'RESOLVED', 'COMPLETED']);

function hash(...parts) {
  return createHash('sha1').update(parts.join('|')).digest('hex');
}

// Instatus reports component statuses as single concatenated words
// (e.g. PARTIALOUTAGE) with no separator, so map the known values explicitly.
const STATUS_LABELS = {
  OPERATIONAL: 'Operational',
  UNDERMAINTENANCE: 'Under maintenance',
  DEGRADEDPERFORMANCE: 'Degraded performance',
  PARTIALOUTAGE: 'Partial outage',
  MAJOROUTAGE: 'Major outage',
};

function humanStatus(status) {
  if (!status) return '';
  const known = STATUS_LABELS[status.toUpperCase()];
  if (known) return known;
  return status
    .toLowerCase()
    .replace(/_/g, ' ')
    .replace(/\b\w/g, (c) => c.toUpperCase());
}

// Pull affected component/group names off an upstream incident, tolerating the
// several shapes Instatus has used (components / affectedComponents, objects or
// strings).
function affectedNames(item) {
  const raw = item.components ?? item.affectedComponents ?? item.affected ?? [];
  const names = new Set();
  for (const c of Array.isArray(raw) ? raw : []) {
    if (typeof c === 'string') names.add(c);
    else if (c && typeof c === 'object') {
      if (c.name) names.add(c.name);
      if (c.group?.name) names.add(c.group.name);
    }
  }
  return [...names];
}

// The public summary endpoints don't attach components to incidents, so most
// incidents arrive with no affected list at all - which the notifier treats as
// global and sends to every device regardless of network filter. Recover the
// networks by matching known component/group names against the incident title
// (e.g. "CityFibre Outage | Crawley" -> ["CityFibre"]). Boundary-checked so a
// short name can't match inside a longer word.
function inferAffectedFromTitle(title, knownNames) {
  if (!title) return [];
  return knownNames.filter((name) => {
    const escaped = name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    return new RegExp(`(^|[^a-z0-9])${escaped}([^a-z0-9]|$)`, 'i').test(title);
  });
}

function normalizeIncident(item, kind, knownNames) {
  const status = String(item.status ?? 'INVESTIGATING').toUpperCase();
  const name = item.name ?? (kind === 'maintenance' ? 'Scheduled maintenance' : 'Incident');
  const affected = affectedNames(item);
  return {
    externalId: String(item.id),
    kind,
    name,
    status,
    impact: item.impact ?? null,
    url: item.url ?? null,
    affected: affected.length ? affected : inferAffectedFromTitle(name, knownNames),
    startedAt: item.started ?? item.start ?? item.startedAt ?? null,
    notifiedHash: hash(status),
  };
}

// Reconcile active incidents/maintenances from the summary against stored
// state, notifying on new items, status changes and resolutions.
async function reconcileIncidents(summary, coldStart, knownNames) {
  const stored = await incidentsRepo.getAll();
  const active = [
    ...summary.activeIncidents.map((i) => normalizeIncident(i, 'incident', knownNames)),
    ...summary.activeMaintenances.map((m) => normalizeIncident(m, 'maintenance', knownNames)),
  ];
  const activeIds = new Set(active.map((i) => i.externalId));

  for (const item of active) {
    const prev = stored.get(item.externalId);
    if (!prev) {
      await incidentsRepo.insert(item);
      if (!coldStart) {
        await notify({
          type: item.kind,
          incidentId: item.externalId,
          url: item.url,
          title: item.kind === 'maintenance' ? 'Scheduled maintenance' : 'New incident',
          body: item.name,
          affected: item.affected,
        });
      }
    } else if (prev.notified_hash !== item.notifiedHash) {
      await incidentsRepo.update(item.externalId, item);
      await notify({
        type: item.kind,
        incidentId: item.externalId,
        url: item.url,
        title: item.kind === 'maintenance' ? 'Maintenance update' : 'Incident update',
        body: `${item.name} - ${humanStatus(item.status)}`,
        affected: item.affected,
      });
    } else {
      // Keep mutable fields fresh without re-notifying.
      await incidentsRepo.update(item.externalId, item);
    }
  }

  // Anything we had marked active but is no longer in the summary has resolved.
  for (const [externalId, row] of stored) {
    if (row.resolved || activeIds.has(externalId)) continue;
    await incidentsRepo.markResolved(externalId);
    if (!coldStart) {
      await notify({
        type: row.kind,
        incidentId: externalId,
        url: row.url,
        title: row.kind === 'maintenance' ? 'Maintenance complete' : 'Incident resolved',
        body: row.name,
        affected: row.affected ?? [],
      });
    }
  }
}

// Detect component health transitions (e.g. Operational -> Degraded) and alert
// devices subscribed to component-level updates.
async function reconcileComponents(components, coldStart) {
  const stored = await componentsRepo.getAll();

  for (const c of components) {
    const externalId = String(c.id);
    const status = String(c.status ?? 'OPERATIONAL').toUpperCase();
    const groupName = c.group?.name ?? null;
    const prev = stored.get(externalId);

    await componentsRepo.upsert({ externalId, name: c.name, groupName, status });

    if (coldStart || !prev || prev.status === status) continue;

    const recovered = OPERATIONAL.has(status);
    await notify({
      type: 'component',
      incidentId: externalId,
      url: null,
      title: c.name,
      body: recovered ? 'Back to operational' : humanStatus(status),
      affected: [groupName, c.name].filter(Boolean),
    });
  }
}

export async function pollOnce() {
  const [summary, components] = await Promise.all([fetchSummary(), fetchComponents()]);

  // On an empty database, seed state silently so a fresh deploy doesn't blast a
  // notification for every pre-existing incident and component.
  const storedIncidents = await incidentsRepo.getAll();
  const storedComponents = await componentsRepo.getAll();
  const coldStartIncidents = storedIncidents.size === 0;
  const coldStartComponents = storedComponents.size === 0;

  // Component and group names double as the vocabulary for inferring which
  // networks an incident affects from its title.
  const knownNames = [
    ...new Set(components.flatMap((c) => [c.name, c.group?.name].filter(Boolean))),
  ];

  await reconcileIncidents(summary, coldStartIncidents, knownNames);
  await reconcileComponents(components, coldStartComponents);
}

let timer = null;

export function startPolling() {
  const tick = async () => {
    try {
      await pollOnce();
    } catch (err) {
      logger.error('poll failed', { error: err.message });
    }
  };
  tick(); // run immediately on boot
  timer = setInterval(tick, config.status.pollIntervalMs);
  logger.info('poller started', { intervalMs: config.status.pollIntervalMs });
}

export function stopPolling() {
  if (timer) clearInterval(timer);
  timer = null;
}
