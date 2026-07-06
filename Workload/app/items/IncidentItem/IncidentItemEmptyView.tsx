import React from "react";
import { useTranslation } from "react-i18next";
import { ItemEditorEmptyView } from "../../components/ItemEditor";
import "./IncidentItem.scss";

interface IncidentItemEmptyViewProps {
  /** Set when the item has no smIncidentId yet, or when the SM API fetch failed. */
  reason: "not-linked" | "fetch-failed";
  detail?: string;
}

/**
 * Shown when this Fabric item is not (yet) bound to a Sound Management
 * incident, or the fetch to SM's API failed. Incidents are discovered and
 * created by SM's own monitoring, never authored by a user in the Fabric
 * portal, so there is no "create/getting started" flow here - only these
 * two failure states.
 */
export function IncidentItemEmptyView({ reason, detail }: IncidentItemEmptyViewProps) {
  const { t } = useTranslation();

  const title = reason === "not-linked"
    ? t('IncidentItemEmptyView_NotLinked_Title', 'Not yet linked to Sound Management')
    : t('IncidentItemEmptyView_FetchFailed_Title', 'Could not load incident data');

  const description = reason === "not-linked"
    ? t('IncidentItemEmptyView_NotLinked_Description', 'This item has no bound incident. Sound Management creates and binds these items automatically when it detects a new incident.')
    : (detail ?? t('IncidentItemEmptyView_FetchFailed_Description', 'The request to Sound Management\'s API did not succeed.'));

  return (
    <ItemEditorEmptyView
      title={title}
      description={description}
      imageSrc="/assets/items/IncidentItem/EditorEmpty.svg"
      imageAlt="Empty state illustration"
      tasks={[]}
    />
  );
}
