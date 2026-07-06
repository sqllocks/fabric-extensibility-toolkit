import React, { useEffect, useState, useCallback } from "react";
import { useParams } from "react-router-dom";
import { useTranslation } from "react-i18next";
import { PageProps, ContextProps } from "../../App";
import { ItemWithDefinition, getWorkloadItem, callGetItem } from "../../controller/ItemCRUDController";
import { callOpenSettings } from "../../controller/SettingsController";
import { ItemEditor, useViewNavigation } from "../../components/ItemEditor";
import { IncidentItemDefinition } from "./IncidentItemDefinition";
import { IncidentItemEmptyView } from "./IncidentItemEmptyView";
import { IncidentItemDefaultView } from "./IncidentItemDefaultView";
import { IncidentItemRibbon } from "./IncidentItemRibbon";
import { IncidentDetail } from "./ItemDetailsSection";
import "./IncidentItem.scss";

export const EDITOR_VIEW_TYPES = {
  EMPTY: 'empty',
  DEFAULT: 'default',
} as const;

type LoadState =
  | { kind: 'loading' }
  | { kind: 'not-linked' }
  | { kind: 'fetch-failed'; detail: string }
  | { kind: 'ready'; incident: IncidentDetail };

const SM_API_BASE_URL = process.env.SM_API_BASE_URL;

export function IncidentItemEditor(props: PageProps) {
  const { workloadClient } = props;
  const pageContext = useParams<ContextProps>();
  const { t } = useTranslation();

  const [item, setItem] = useState<ItemWithDefinition<IncidentItemDefinition>>();
  const [state, setState] = useState<LoadState>({ kind: 'loading' });
  const [viewSetter, setViewSetter] = useState<((view: string) => void) | null>(null);

  const fetchIncident = useCallback(async (smIncidentId: string) => {
    try {
      const { token } = await workloadClient.auth.acquireFrontendAccessToken({ scopes: [] });
      const res = await fetch(`${SM_API_BASE_URL}/incidents/${smIncidentId}`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      if (!res.ok) throw new Error(`Sound Management API returned ${res.status}`);
      const incident = (await res.json()) as IncidentDetail;
      setState({ kind: 'ready', incident });
    } catch (err: any) {
      setState({ kind: 'fetch-failed', detail: err?.message ?? String(err) });
    }
  }, [workloadClient]);

  const loadDataFromUrl = useCallback(async (ctx: ContextProps) => {
    if (!ctx.itemObjectId) {
      // Non-editor context (e.g. a route outside the item editor) - nothing to load.
      return;
    }
    setState({ kind: 'loading' });
    try {
      const loadedItem = await getWorkloadItem<IncidentItemDefinition>(workloadClient, ctx.itemObjectId);
      setItem(loadedItem);
      const smIncidentId = loadedItem?.definition?.smIncidentId;
      if (!smIncidentId) {
        setState({ kind: 'not-linked' });
        return;
      }
      await fetchIncident(smIncidentId);
    } catch (error: any) {
      setState({ kind: 'fetch-failed', detail: error?.message ?? String(error) });
    }
  }, [workloadClient, fetchIncident]);

  useEffect(() => {
    loadDataFromUrl(pageContext);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [pageContext.itemObjectId]);

  const handleOpenSettings = async () => {
    if (item) {
      try {
        const item_res = await callGetItem(workloadClient, item.id);
        await callOpenSettings(workloadClient, item_res.item, 'About');
      } catch (error) {
        console.error('Failed to open settings:', error);
      }
    }
  };

  const handleRefresh = async () => {
    const smIncidentId = item?.definition?.smIncidentId;
    if (smIncidentId) await fetchIncident(smIncidentId);
  };

  const EmptyOrErrorView = () => {
    useViewNavigation();
    if (state.kind === 'fetch-failed') {
      return <IncidentItemEmptyView reason="fetch-failed" detail={state.detail} />;
    }
    return <IncidentItemEmptyView reason="not-linked" />;
  };

  const views = [
    { name: EDITOR_VIEW_TYPES.EMPTY, component: <EmptyOrErrorView /> },
    {
      name: EDITOR_VIEW_TYPES.DEFAULT,
      component: state.kind === 'ready'
        ? <IncidentItemDefaultView incident={state.incident} />
        : <></>,
    },
  ];

  useEffect(() => {
    if (viewSetter) {
      viewSetter(state.kind === 'ready' ? EDITOR_VIEW_TYPES.DEFAULT : EDITOR_VIEW_TYPES.EMPTY);
    }
  }, [state.kind, viewSetter]);

  return (
    <ItemEditor
      isLoading={state.kind === 'loading'}
      loadingMessage={t("IncidentItemEditor_Loading", "Loading incident...")}
      ribbon={(context) => (
        <IncidentItemRibbon
          {...props}
          viewContext={context}
          refreshCallback={handleRefresh}
          openSettingsCallback={handleOpenSettings}
        />
      )}
      messageBar={[]}
      views={views}
      viewSetter={(setCurrentView) => {
        if (!viewSetter) setViewSetter(() => setCurrentView);
      }}
    />
  );
}
