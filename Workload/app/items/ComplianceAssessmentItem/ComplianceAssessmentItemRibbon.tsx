import React from "react";
import { ArrowSync24Regular } from "@fluentui/react-icons";
import { useTranslation } from "react-i18next";
import { PageProps } from '../../App';
import {
  Ribbon,
  RibbonAction,
  createSettingsAction
} from '../../components/ItemEditor';
import { ViewContext } from '../../components';

/**
 * Props interface for the ComplianceAssessment Ribbon component. No save
 * action: this item is a read-only view of a Sound Management compliance
 * assessment, not editable Fabric-native content.
 */
export interface ComplianceAssessmentItemRibbonProps extends PageProps {
  viewContext: ViewContext;
  refreshCallback: () => Promise<void>;
  openSettingsCallback: () => Promise<void>;
}

export function ComplianceAssessmentItemRibbon(props: ComplianceAssessmentItemRibbonProps) {
  const { viewContext } = props;
  const { t } = useTranslation();

  const settingsAction = createSettingsAction(props.openSettingsCallback);

  const homeToolbarActions: RibbonAction[] = [
    {
      key: 'refresh-assessment',
      icon: ArrowSync24Regular,
      label: t("ComplianceAssessmentItemRibbon_Refresh_Label", "Refresh"),
      onClick: props.refreshCallback,
      testId: 'ribbon-refresh-btn',
      tooltip: t("ComplianceAssessmentItemRibbon_Refresh_Tooltip", "Reload the latest assessment data from Sound Management"),
    },
    settingsAction,
  ];

  return (
    <Ribbon
      homeToolbarActions={homeToolbarActions}
      additionalToolbars={[]}
      viewContext={viewContext}
    />
  );
}
