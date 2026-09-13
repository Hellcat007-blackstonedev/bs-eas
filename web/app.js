const currentContainer = document.getElementById('current-alert');
const historyContainer = document.getElementById('alert-history');

const esc = (value) =>
    String(value ?? '')
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');

const time = (timestamp) => {
    try {
        return new Date(timestamp * 1000).toLocaleString();
    } catch (_) {
        return '';
    }
};

const levelLabel = (level) => {
    if (level === 'emergency') return 'EMERGENCY WARNING';
    if (level === 'warning') return 'WARNING';
    if (level === 'all_clear') return 'ALL CLEAR';
    return 'ADVICE';
};

const levelClass = (level) => {
    if (level === 'emergency') return 'emergency';
    if (level === 'warning') return 'warning';
    if (level === 'all_clear') return 'all_clear';
    return 'advice';
};

const iconFile = (alert) => {
    const type = String(alert?.type || '').toLowerCase();
    if (type === 'wildfire') return 'wildfire.svg';
    if (type === 'tornado_warning' || type.includes('tornado')) return 'tornado.svg';
    if (type === 'earthquake') return 'earthquake.svg';
    if (type === 'tsunami_warning' || type.includes('tsunami')) return 'tsunami.svg';
    if (type === 'structure_fire') return 'structure-fire.svg';
    if (type === 'hazmat') return 'hazmat.svg';
    return 'generic.svg';
};

function revisionName(revision, index) {
    if (index === 0) return 'ORIGINAL ALERT';
    if (revision.eventType === 'reactivated') return 'REACTIVATED';
    if (revision.eventType === 'all_clear') return 'ALL CLEAR';
    return `UPDATE ${index}`;
}

/* History intentionally contains PREVIOUS revisions only.
   The current alert is already displayed directly above it. */
function incidentHistory(alert) {
    const revisions = Array.isArray(alert.revisions) ? alert.revisions : [];

    if (revisions.length === 0) {
        return '';
    }

    const previous = revisions.map((revision, index) => {
        const revisionLevel = revision.level || 'advice';

        return `
            <div class="incident-history-item ${levelClass(revisionLevel)}">
                <div class="incident-history-icon">
                    <span class="hazard-mask" style="--hazard-icon:url(\'icons/${iconFile(alert)}\')"></span>
                </div>
                <div class="incident-history-copy">
                    <div class="incident-history-meta">
                        <strong>${esc(revisionName(revision, index))}</strong>
                        <span>${esc(levelLabel(revisionLevel))} • ${esc(time(revision.timestamp))}</span>
                    </div>
                    <div class="incident-history-headline">${esc(revision.headline || '')}</div>
                    <div class="incident-history-message">${esc(revision.message || '')}</div>
                    ${
                        revision.issuer
                            ? `<div class="incident-history-issuer">Issued by ${esc(revision.issuer)}</div>`
                            : ''
                    }
                </div>
            </div>
        `;
    }).join('');

    return `
        <details class="incident-history">
            <summary>Incident History (${revisions.length})</summary>
            <div class="incident-history-list">${previous}</div>
        </details>
    `;
}

function card(alert) {
    const level =
        alert.status === 'cleared'
            ? 'all_clear'
            : (alert.level || 'advice');

    const updated =
        alert.updatedAt &&
        alert.updatedAt !== alert.timestamp;

    const title =
        level === 'all_clear'
            ? 'ALL CLEAR'
            : `${updated ? 'UPDATED: ' : ''}${alert.title || 'EMERGENCY ALERT'}`;

    return `
        <article class="alert-card ${level}">
            <div class="alert-content">
                <div class="alert-type">${esc(title)}</div>

                <div class="alert-main">
                    <div class="alert-icon">
                        <span class="hazard-mask" style="--hazard-icon:url(\'icons/${iconFile(alert)}\')"></span>
                    </div>

                    <div class="alert-copy">
                        <h2>${esc(alert.headline)}</h2>
                        <div class="alert-message">${esc(alert.message)}</div>
                    </div>
                </div>

                ${
                    alert.zoneLabels?.length
                        ? `<div class="alert-zones">Affected areas: ${esc(alert.zoneLabels.join(', '))}</div>`
                        : ''
                }

                <div class="alert-footer">
                    <div class="issuer">Issued by ${esc(alert.issuer)}</div>
                    <div class="time">${esc(time(alert.updatedAt || alert.timestamp))}${updated ? ' • Updated' : ''}</div>
                </div>

                ${incidentHistory(alert)}
            </div>
        </article>
    `;
}

function resolveResourceName() {
    // When this page is embedded inside another resource (for example
    // qs-smartphone), GetParentResourceName() can resolve to the host resource
    // instead of bs-EAS. Prefer the resource name from this iframe's own
    // cfx-nui hostname so renamed copies such as bs-eas-public work correctly.
    const host = String(window.location.hostname || '');
    if (host.startsWith('cfx-nui-')) {
        return host.substring('cfx-nui-'.length);
    }

    if (typeof GetParentResourceName === 'function') {
        return GetParentResourceName();
    }

    return 'bs-eas';
}

async function load() {
    const resourceName = resolveResourceName();

    try {
        const response = await fetch(
            `https://${resourceName}/getAlerts`,
            {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: '{}'
            }
        );

        const data = await response.json();
        const alerts = data.alerts || [];

        const active = alerts.filter((alert) => alert.status === 'active');
        const past = alerts.filter((alert) => alert.status !== 'active');

        currentContainer.innerHTML =
            active.length
                ? active.map(card).join('')
                : '<div class="empty">No active emergency alerts.</div>';

        historyContainer.innerHTML =
            past.length
                ? past.map(card).join('')
                : '<div class="empty">No previous alerts.</div>';
    } catch (error) {
        console.error('[bs-eas] Failed to load alerts:', error);
        currentContainer.innerHTML =
            '<div class="empty">Unable to load alerts.</div>';
    }
}

load();
setInterval(load, 10000);
