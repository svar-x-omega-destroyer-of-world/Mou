'use client';

import { useState } from 'react';
import { Cluster, Confidence, RootCause, ROOT_CAUSE_ICONS, ROOT_CAUSE_LABELS } from '../types';

function ConfidenceBadge({ confidence }: { confidence: Confidence }) {
  const styles: Record<Confidence, string> = {
    high: 'bg-green-100 text-green-800 border-green-200',
    medium: 'bg-amber-100 text-amber-800 border-amber-200',
    low: 'bg-red-100 text-red-800 border-red-200',
  };
  return (
    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold border ${styles[confidence]}`}>
      {confidence.charAt(0).toUpperCase() + confidence.slice(1)}
    </span>
  );
}

function RootCauseBadge({ cause }: { cause: RootCause }) {
  const colors: Record<RootCause, string> = {
    name_mismatch: 'bg-blue-50 text-blue-800 border-blue-200',
    dob_mismatch: 'bg-purple-50 text-purple-800 border-purple-200',
    seeding_gap: 'bg-cyan-50 text-cyan-800 border-cyan-200',
    ekyc_incomplete: 'bg-orange-50 text-orange-800 border-orange-200',
    biometric_failure: 'bg-rose-50 text-rose-800 border-rose-200',
    unknown: 'bg-gray-50 text-gray-700 border-gray-200',
  };
  return (
    <span className={`inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-sm font-semibold border ${colors[cause]}`}>
      <span>{ROOT_CAUSE_ICONS[cause]}</span>
      {ROOT_CAUSE_LABELS[cause]}
    </span>
  );
}

function ClusterRow({ cluster, rank }: { cluster: Cluster; rank: number }) {
  const [expanded, setExpanded] = useState(false);

  return (
    <div className="border border-gray-200 rounded-xl overflow-hidden shadow-sm">
      <button
        onClick={() => setExpanded(!expanded)}
        className="w-full text-left bg-white hover:bg-gray-50 transition-colors p-5"
        aria-expanded={expanded}
      >
        <div className="flex items-start gap-4">
          <div className="flex-shrink-0 w-9 h-9 rounded-full bg-green-700 text-white flex items-center justify-center text-sm font-bold">
            {rank}
          </div>
          <div className="flex-1 min-w-0">
            <div className="flex flex-wrap items-center gap-2 mb-2">
              <RootCauseBadge cause={cluster.root_cause} />
              <ConfidenceBadge confidence={cluster.confidence} />
            </div>
            <div className="flex flex-wrap items-center gap-x-4 gap-y-1">
              <span className="text-gray-700 font-medium truncate">📍 {cluster.fps_location}</span>
              <span className="text-2xl font-extrabold text-green-700">
                {cluster.beneficiaries_affected}
                <span className="text-sm font-medium text-gray-500 ml-1">people affected</span>
              </span>
            </div>
          </div>
          <div className="flex-shrink-0 text-gray-400 text-lg select-none">
            {expanded ? '▲' : '▼'}
          </div>
        </div>
      </button>

      {expanded && (
        <div className="border-t border-gray-100 bg-gray-50 px-5 py-4">
          <p className="text-xs font-semibold text-gray-500 uppercase tracking-widest mb-3">
            Anonymised Cases ({cluster.cases.length})
          </p>
          {cluster.cases.length === 0 ? (
            <p className="text-sm text-gray-400 italic">No individual cases recorded.</p>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="text-left text-gray-500 border-b border-gray-200">
                    <th className="pb-2 pr-6 font-semibold">Case ID</th>
                    <th className="pb-2 font-semibold">Document Pattern</th>
                  </tr>
                </thead>
                <tbody>
                  {cluster.cases.map((c) => (
                    <tr key={c.case_id} className="border-b border-gray-100 last:border-0">
                      <td className="py-2 pr-6 font-mono text-gray-600">{c.case_id}</td>
                      <td className="py-2 text-gray-700">{c.pattern}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      )}
    </div>
  );
}

export default function ClusterList({ clusters }: { clusters: Cluster[] }) {
  const totalBeneficiaries = clusters.reduce((sum, c) => sum + c.beneficiaries_affected, 0);
  const totalCases = clusters.reduce((sum, c) => sum + c.cases.length, 0);

  return (
    <div>
      {/* Summary stats */}
      <div className="grid grid-cols-3 gap-4 mb-8">
        <div className="bg-green-50 border border-green-200 rounded-xl p-4 text-center">
          <div className="text-3xl font-extrabold text-green-700">{totalBeneficiaries}</div>
          <div className="text-sm text-green-800 font-medium mt-1">Beneficiaries affected</div>
        </div>
        <div className="bg-blue-50 border border-blue-200 rounded-xl p-4 text-center">
          <div className="text-3xl font-extrabold text-blue-700">{clusters.length}</div>
          <div className="text-sm text-blue-800 font-medium mt-1">Active clusters</div>
        </div>
        <div className="bg-gray-50 border border-gray-200 rounded-xl p-4 text-center">
          <div className="text-3xl font-extrabold text-gray-700">{totalCases}</div>
          <div className="text-sm text-gray-600 font-medium mt-1">Logged diagnoses</div>
        </div>
      </div>

      {/* Cluster list */}
      <div className="space-y-3">
        {clusters.map((cluster, i) => (
          <ClusterRow key={`${cluster.root_cause}-${cluster.fps_location}`} cluster={cluster} rank={i + 1} />
        ))}
      </div>

      {clusters.length === 0 && (
        <div className="text-center py-16 text-gray-400">
          <div className="text-5xl mb-4">📭</div>
          <p className="text-lg font-medium">No clusters yet</p>
          <p className="text-sm mt-1">Diagnoses will appear here as they come in.</p>
        </div>
      )}
    </div>
  );
}
