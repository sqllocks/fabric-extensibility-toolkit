import React from "react";
import { ItemEditorDefaultView } from "../../components/ItemEditor";
import { ItemDetailsSection, IncidentDetail } from "./ItemDetailsSection";
import "./IncidentItem.scss";

interface IncidentItemDefaultViewProps {
  incident: IncidentDetail;
}

export function IncidentItemDefaultView({ incident }: IncidentItemDefaultViewProps) {
  return (
    <ItemEditorDefaultView
      center={{
        content: <ItemDetailsSection incident={incident} />,
      }}
    />
  );
}
