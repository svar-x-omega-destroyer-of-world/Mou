export type RootCause =
  | 'name_mismatch'
  | 'dob_mismatch'
  | 'seeding_gap'
  | 'ekyc_incomplete'
  | 'biometric_failure'
  | 'unknown';

export type Confidence = 'high' | 'medium' | 'low';

export interface Case {
  case_id: string;
  pattern: string;
}

export interface Cluster {
  root_cause: RootCause;
  fps_location: string;
  beneficiaries_affected: number;
  confidence: Confidence;
  cases: Case[];
}

export const ROOT_CAUSE_LABELS: Record<RootCause, string> = {
  name_mismatch: 'Name Mismatch',
  dob_mismatch: 'Date of Birth Mismatch',
  seeding_gap: 'Aadhaar Seeding Gap',
  ekyc_incomplete: 'e-KYC Incomplete',
  biometric_failure: 'Biometric Failure',
  unknown: 'Unknown',
};

export const ROOT_CAUSE_ICONS: Record<RootCause, string> = {
  name_mismatch: '🔤',
  dob_mismatch: '📅',
  seeding_gap: '🔗',
  ekyc_incomplete: '🪪',
  biometric_failure: '👆',
  unknown: '❓',
};
