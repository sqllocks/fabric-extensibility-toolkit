
/**
 * Definition of a Compliance Assessment item, stored in Fabric's own
 * item-definition storage. Per the confirmed per-record design, one Fabric
 * item binds to exactly one compliance_assessments.id. SM's backend sets
 * smAssessmentId when it creates this Fabric item (SM generates assessments
 * from its own compliance engine; the item is never created by a user in
 * the Fabric portal first).
 */
export interface ComplianceAssessmentItemDefinition {
  smAssessmentId?: string;
}
