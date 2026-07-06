import React from "react";
import { Badge, Card, CardHeader, Text } from "@fluentui/react-components";
import { useTranslation } from "react-i18next";
import "./ComplianceAssessmentItem.scss";

export interface ComplianceControl {
  id: string;
  controlId: string;
  controlName: string;
  status: string;
  score: string;
  lastEvaluatedAt: string;
}

export interface ComplianceAssessmentDetail {
  id: string;
  framework: string;
  overallScore: string;
  controlCount: number;
  passingCount: number;
  failingCount: number;
  isCurrent: boolean;
  assessedAt: string;
  controls: ComplianceControl[];
}

interface ItemDetailsSectionProps {
  assessment: ComplianceAssessmentDetail;
}

export function ItemDetailsSection({ assessment }: ItemDetailsSectionProps) {
  const { t } = useTranslation();

  return (
    <div className="compliance-detail-view">
      <Card className="compliance-detail-card">
        <CardHeader
          header={<Text weight="semibold" size={600}>{assessment.framework}</Text>}
          description={<Text>{t('Compliance_OverallScore_Label', 'Overall score')}: {assessment.overallScore}</Text>}
        />
        <div className="compliance-detail-badges">
          <Badge color={assessment.isCurrent ? "success" : "informative"} appearance="filled">
            {assessment.isCurrent
              ? t('Compliance_Current_Badge', 'Current')
              : t('Compliance_Historical_Badge', 'Historical')}
          </Badge>
          <Badge appearance="outline">{assessment.passingCount}/{assessment.controlCount} {t('Compliance_Passing_Label', 'passing')}</Badge>
        </div>
        <div className="compliance-detail-row">
          <span className="compliance-detail-label">{t('Compliance_AssessedAt_Label', 'Assessed at')}</span>
          <span className="compliance-detail-value">{new Date(assessment.assessedAt).toLocaleString()}</span>
        </div>
      </Card>

      <Card className="compliance-controls-card">
        <CardHeader header={<Text weight="semibold">{t('Compliance_Controls_Title', 'Controls')} ({assessment.controls.length})</Text>} />
        <div className="compliance-controls-list">
          {assessment.controls.map((c) => (
            <div key={c.id} className="compliance-control-row">
              <span className="compliance-control-id">{c.controlId}</span>
              <span className="compliance-control-name">{c.controlName}</span>
              <Badge color={c.status === 'pass' ? "success" : "danger"} appearance="outline">
                {c.status}
              </Badge>
              <span className="compliance-control-score">{c.score}</span>
            </div>
          ))}
        </div>
      </Card>
    </div>
  );
}
