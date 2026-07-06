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
 * Props interface for the Incident Ribbon component. No save action: this
 * item is a read-only view of a Sound Management incident, not editable
 * Fabric-native content.
 */
export interface IncidentItemRibbonProps extends PageProps {
  viewContext: ViewContext;
  refreshCallback: () => Promise<void>;
  openSettingsCallback: () => Promise<void>;
}

export function IncidentItemRibbon(props: IncidentItemRibbonProps) {
  const { viewContext } = props;
  const { t } = useTranslation();

  const settingsAction = createSettingsAction(props.openSettingsCallback);

  const homeToolbarActions: RibbonAction[] = [
    {
      key: 'refresh-incident',
      icon: ArrowSync24Regular,
      label: t("IncidentItemRibbon_Refresh_Label", "Refresh"),
      onClick: props.refreshCallback,
      testId: 'ribbon-refresh-btn',
      tooltip: t("IncidentItemRibbon_Refresh_Tooltip", "Reload the latest incident data from Sound Management"),
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
