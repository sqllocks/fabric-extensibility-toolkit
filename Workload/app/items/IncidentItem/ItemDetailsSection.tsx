import React from "react";
import { Badge, Card, CardHeader, Text } from "@fluentui/react-components";
import { useTranslation } from "react-i18next";
import "./IncidentItem.scss";

export interface IncidentDetail {
  id: string;
  assetId: string | null;
  assetName: string;
  earliestFailingInvariant: string | null;
  severity: string;
  status: string;
  createdAt: string;
  confidenceScore: number;
  affectedDownstream: string[];
}

interface ItemDetailsSectionProps {
  incident: IncidentDetail;
}

const SEVERITY_COLOR: Record<string, "danger" | "warning" | "important" | "informative"> = {
  critical: "danger",
  high: "warning",
  medium: "important",
  low: "informative",
};

export function ItemDetailsSection({ incident }: ItemDetailsSectionProps) {
  const { t } = useTranslation();

  return (
    <div className="incident-detail-view">
      <Card className="incident-detail-card">
        <CardHeader
          header={<Text weight="semibold" size={600}>{incident.assetName}</Text>}
          description={
            <Text>{incident.earliestFailingInvariant ?? t('Incident_NoInvariant', 'No failing invariant recorded')}</Text>
          }
        />
        <div className="incident-detail-badges">
          <Badge color={SEVERITY_COLOR[incident.severity] ?? "informative"} appearance="filled">
            {incident.severity.toUpperCase()}
          </Badge>
          <Badge appearance="outline">{incident.status}</Badge>
        </div>
        <div className="incident-detail-grid">
          <div className="incident-detail-row">
            <span className="incident-detail-label">{t('Incident_Confidence_Label', 'Confidence')}</span>
            <span className="incident-detail-value">{Math.round(incident.confidenceScore * 100)}%</span>
          </div>
          <div className="incident-detail-row">
            <span className="incident-detail-label">{t('Incident_Created_Label', 'Detected')}</span>
            <span className="incident-detail-value">{new Date(incident.createdAt).toLocaleString()}</span>
          </div>
          <div className="incident-detail-row">
            <span className="incident-detail-label">{t('Incident_Asset_Label', 'Asset ID')}</span>
            <span className="incident-detail-value">{incident.assetId ?? 'N/A'}</span>
          </div>
          <div className="incident-detail-row">
            <span className="incident-detail-label">{t('Incident_Downstream_Label', 'Affected downstream assets')}</span>
            <span className="incident-detail-value">{incident.affectedDownstream.length}</span>
          </div>
        </div>
      </Card>
    </div>
  );
}
