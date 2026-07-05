import React from "react";
import { useTranslation } from "react-i18next";

import { WorkloadClientAPI } from "@ms-fabric/workload-client";
import { ItemWithDefinition } from "../../controller/ItemCRUDController";
import { ComplianceAssessmentItemDefinition } from "./ComplianceAssessmentItemDefinition";
import { ItemEditorEmptyView, EmptyStateTask } from "../../components/ItemEditor";
import "./ComplianceAssessmentItem.scss";

interface ComplianceAssessmentItemEmptyViewProps {
  workloadClient: WorkloadClientAPI;
  item?: ItemWithDefinition<ComplianceAssessmentItemDefinition>;
  onNavigateToGettingStarted: () => void;
}

/**
 * Empty state component - the first screen users see
 * This is a static page that can be easily removed or replaced by developers
 * 
 * To skip this page, modify ComplianceAssessmentItemEditor.tsx line 25,55
 * to always set currentView to 'getting-started'
 * 
 * This component uses the ItemEditorEmptyView control for consistency
 * across all item types.
 */
export function ComplianceAssessmentItemEmptyView({
  workloadClient,
  item,
  onNavigateToGettingStarted
}: ComplianceAssessmentItemEmptyViewProps) {
  const { t } = useTranslation();

  // Define onboarding tasks
  const tasks: EmptyStateTask[] = [
    {
      id: 'getting-started',
      label: t('ComplianceAssessmentItemEmptyView_StartButton', 'Getting Started'),
      icon: undefined,
      description: t('ComplianceAssessmentItemEmptyView_StartButton_Description', 'Learn how to set up your ComplianceAssessment item.'),
      onClick: onNavigateToGettingStarted,
    }
  ];

  return (
    <ItemEditorEmptyView
      title={t('ComplianceAssessmentItemEmptyView_Title', 'Welcome to ComplianceAssessment!')}
      description={t('ComplianceAssessmentItemEmptyView_Description', 'This is the first screen people will see after an item is created. Include some basic information to help them continue.')}
      imageSrc="/assets/items/ComplianceAssessmentItem/EditorEmpty.svg"
      imageAlt="Empty state illustration"
      tasks={tasks}
    />
  );
}
