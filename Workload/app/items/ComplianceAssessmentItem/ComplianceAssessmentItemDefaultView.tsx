import React from "react";
import { ItemEditorDefaultView } from "../../components/ItemEditor";
import { ItemDetailsSection, ComplianceAssessmentDetail } from "./ItemDetailsSection";
import "./ComplianceAssessmentItem.scss";

interface ComplianceAssessmentItemDefaultViewProps {
  assessment: ComplianceAssessmentDetail;
}

export function ComplianceAssessmentItemDefaultView({ assessment }: ComplianceAssessmentItemDefaultViewProps) {
  return (
    <ItemEditorDefaultView
      center={{
        content: <ItemDetailsSection assessment={assessment} />,
      }}
    />
  );
}
