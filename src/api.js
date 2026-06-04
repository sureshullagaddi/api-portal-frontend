/**
 * api.js — all HTTP calls to the backend Lambda.
 * API endpoint is injected at runtime via window.__CONFIG__ (from config.js in S3).
 * Falls back to VITE env var for local development.
 */

const BASE_URL =
  window.__CONFIG__?.apiEndpoint ||
  import.meta.env.VITE_API_ENDPOINT ||
  'http://localhost:3000';

async function request(path, options = {}) {
  let res;
  try {
    res = await fetch(`${BASE_URL}${path}`, {
      headers: { 'Content-Type': 'application/json', ...options.headers },
      ...options,
    });
  } catch (networkErr) {
    throw Object.assign(new Error('Cannot reach backend — check your network or server'), {
      details: null, status: 0,
    });
  }

  let data;
  try {
    data = await res.json();
  } catch {
    throw Object.assign(
      new Error(`Backend returned a non-JSON response (HTTP ${res.status})`),
      { details: null, status: res.status },
    );
  }

  if (!res.ok) {
    const detail = data.details;
    let message = data.error ?? 'Request failed';
    if (detail && typeof detail === 'object' && detail.message && detail.message !== message) {
      message = `${message}: [${detail.code ?? 'ERR'}] ${detail.message}`;
    } else if (detail && typeof detail === 'string') {
      message = `${message}: ${detail}`;
    }
    throw Object.assign(new Error(message), { details: data.details, status: res.status });
  }
  return data;
}

export const api = {
  /** Create a new API */
  createApi:  (body)    => request('/apis', { method: 'POST', body: JSON.stringify(body) }),
  /** List all provisioned APIs */
  listApis:   ()        => request('/apis'),
  /** Get one API by name */
  getApi:     (apiName) => request(`/apis/${apiName}`),
  /** Delete an API and all its AWS resources */
  deleteApi:  (apiName) => request(`/apis/${apiName}`, { method: 'DELETE' }),
  /** Force-clear a stuck DELETE_FAILED or FAILED record from registry */
  forceClear: (apiName) => request(`/apis/${apiName}/force-clear`, { method: 'POST' }),
};

