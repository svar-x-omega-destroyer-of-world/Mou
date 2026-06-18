import ClusterList from './components/ClusterList';
import { Cluster } from './types';

const BACKEND_URL = process.env.BACKEND_URL ?? 'http://localhost:8000';

async function getClusters(): Promise<Cluster[]> {
  const res = await fetch(`${BACKEND_URL}/clusters?min_confidence=low`, {
    cache: 'no-store',
  });
  if (!res.ok) throw new Error(`Backend returned ${res.status}`);
  return res.json();
}

export default async function Page() {
  let clusters: Cluster[] = [];
  let error: string | null = null;

  try {
    clusters = await getClusters();
  } catch (e) {
    error = e instanceof Error ? e.message : 'Could not reach the backend.';
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="bg-green-700 text-white shadow-md">
        <div className="max-w-4xl mx-auto px-6 py-5 flex items-center justify-between">
          <div>
            <div className="flex items-center gap-3">
              <span className="text-2xl font-extrabold tracking-tight">Mou</span>
              <span className="text-green-200 text-sm font-medium">Officials Dashboard</span>
            </div>
            <p className="text-green-200 text-sm mt-0.5">
              Ranked systemic exclusion patterns — read-only view
            </p>
          </div>
          <div className="text-right text-xs text-green-300">
            <div>PDS / ONORC Scheme</div>
            <div>Barak Valley region</div>
          </div>
        </div>
      </header>

      <main className="max-w-4xl mx-auto px-6 py-8">
        {/* Page title */}
        <div className="mb-6">
          <h1 className="text-2xl font-bold text-gray-900">Exclusion Clusters</h1>
          <p className="text-gray-500 mt-1 text-sm">
            Grouped by root cause and Fair Price Shop, ranked by number of beneficiaries affected.
            One rejection is a personal misfortune — many at one shop is an accountability report.
          </p>
        </div>

        {error ? (
          <div className="bg-red-50 border border-red-200 rounded-xl p-6 text-center">
            <div className="text-3xl mb-2">⚠️</div>
            <p className="font-semibold text-red-800">Could not load clusters</p>
            <p className="text-sm text-red-600 mt-1">{error}</p>
            <p className="text-xs text-gray-400 mt-3">
              Make sure the backend is running:{' '}
              <code className="bg-gray-100 px-1 rounded">cd backend && uvicorn app.main:app --reload</code>
            </p>
          </div>
        ) : (
          <ClusterList clusters={clusters} />
        )}
      </main>

      <footer className="max-w-4xl mx-auto px-6 py-6 mt-4 border-t border-gray-200">
        <p className="text-xs text-gray-400 text-center">
          Mou — Make Exclusion Visible &nbsp;·&nbsp; Hackathon build June 2026 &nbsp;·&nbsp;
          All data is anonymised. No names or Aadhaar numbers are stored.
        </p>
      </footer>
    </div>
  );
}
