import React from "react";
import { useTranslation } from "react-i18next";

import { WorkloadClientAPI } from "@ms-fabric/workload-client";
import { ItemWithDefinition } from "../../controller/ItemCRUDController";
import { IncidentItemDefinition } from "./IncidentItemDefinition";
import { ItemEditorEmptyView, EmptyStateTask } from "../../components/ItemEditor";
import "./IncidentItem.scss";

interface IncidentItemEmptyViewProps {
  workloadClient: WorkloadClientAPI;
  item?: ItemWithDefinition<IncidentItemDefinition>;
  onNavigateToGettingStarted: () => void;
}

/**
 * Empty state component - the first screen users see
 * This is a static page that can be easily removed or replaced by developers
 * 
 * To skip this page, modify IncidentItemEditor.tsx line 25,55
 * to always set currentView to 'getting-started'
 * 
 * This component uses the ItemEditorEmptyView control for consistency
 * across all item types.
 */
export function IncidentItemEmptyView({
  workloadClient,
  item,
  onNavigateToGettingStarted
}: IncidentItemEmptyViewProps) {
  const { t } = useTranslation();

  // Define onboarding tasks
  const tasks: EmptyStateTask[] = [
    {
      id: 'getting-started',
      label: t('IncidentItemEmptyView_StartButton', 'Getting Started'),
      icon: undefined,
      description: t('IncidentItemEmptyView_StartButton_Description', 'Learn how to set up your Incident item.'),
      onClick: onNavigateToGettingStarted,
    }
  ];

  return (
    <ItemEditorEmptyView
      title={t('IncidentItemEmptyView_Title', 'Welcome to Incident!')}
      description={t('IncidentItemEmptyView_Description', 'This is the first screen people will see after an item is created. Include some basic information to help them continue.')}
      imageSrc="/assets/items/IncidentItem/EditorEmpty.svg"
      imageAlt="Empty state illustration"
      tasks={tasks}
    />
  );
}
