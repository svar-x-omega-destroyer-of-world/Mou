const API_BASE = "http://localhost:8000";

interface Case {
  case_id: string;
  pattern: string;
}

interface Cluster {
  root_cause: string;
  fps_location: string;
  beneficiaries_affected: number;
  confidence: string;
  cases: Case[];
}

async function getClusters(): Promise<Cluster[]> {
  try {
    const res = await fetch(`${API_BASE}/clusters`, { cache: "no-store" });
    if (!res.ok) return [];
    return res.json();
  } catch {
    return [];
  }
}

function confidenceColor(c: string): string {
  switch (c) {
    case "high":   return "bg-emerald-100 text-emerald-800";
    case "medium": return "bg-amber-100 text-amber-800";
    case "low":    return "bg-red-100 text-red-800";
    default:       return "bg-gray-100 text-gray-800";
  }
}

function rootCauseLabel(rc: string): string {
  const labels: Record<string, string> = {
    name_mismatch: "Name Mismatch",
    dob_mismatch: "DOB Mismatch",
    seeding_gap: "Aadhaar Seeding Gap",
    ekyc_incomplete: "eKYC Incomplete",
    biometric_failure: "Biometric Failure",
    unknown: "Unknown",
  };
  return labels[rc] ?? rc;
}

export default async function Home() {
  const clusters = await getClusters();

  return (
    <div className="min-h-dvh bg-zinc-50 p-6 font-sans">
      <header className="mb-8">
        <h1 className="text-2xl font-bold tracking-tight text-zinc-900">
          Mou — Officials Dashboard
        </h1>
        <p className="mt-1 text-sm text-zinc-500">
          Systemic defect clusters ranked by beneficiaries affected
        </p>
      </header>

      {clusters.length === 0 ? (
        <div className="rounded-lg border border-dashed border-zinc-300 p-12 text-center text-zinc-400">
          No clusters available. Make sure the backend is running at {API_BASE}.
        </div>
      ) : (
        <div className="space-y-4">
          {clusters.map((c, i) => (
            <details
              key={`${c.root_cause}-${c.fps_location}-${i}`}
              className="group rounded-lg border border-zinc-200 bg-white shadow-sm transition hover:shadow-md"
            >
              <summary className="flex cursor-pointer items-center gap-4 p-4">
                <span className="flex h-8 w-8 items-center justify-center rounded-full bg-zinc-100 text-sm font-semibold text-zinc-600">
                  {i + 1}
                </span>
                <div className="flex-1">
                  <span className="font-semibold text-zinc-900">
                    {rootCauseLabel(c.root_cause)}
                  </span>
                  <span className="ml-3 text-sm text-zinc-500">
                    {c.fps_location}
                  </span>
                </div>
                <span className="text-lg font-bold text-zinc-800">
                  {c.beneficiaries_affected}
                </span>
                <span className="text-sm text-zinc-400">beneficiaries</span>
                <span
                  className={`rounded-full px-2.5 py-0.5 text-xs font-medium ${confidenceColor(c.confidence)}`}
                >
                  {c.confidence}
                </span>
              </summary>
              <div className="border-t border-zinc-100 p-4">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="text-left text-zinc-400">
                      <th className="pb-2 font-medium">Case ID</th>
                      <th className="pb-2 font-medium">Pattern</th>
                    </tr>
                  </thead>
                  <tbody>
                    {c.cases.map((caseItem) => (
                      <tr key={caseItem.case_id} className="border-t border-zinc-50 text-zinc-700">
                        <td className="py-1.5 font-mono text-xs">
                          {caseItem.case_id}
                        </td>
                        <td className="py-1.5">{caseItem.pattern}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </details>
          ))}
        </div>
      )}
    </div>
  );
}
