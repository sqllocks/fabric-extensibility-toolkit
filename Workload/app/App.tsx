import React from "react";
import { Route, Router, Switch } from "react-router-dom";
import { History } from "history";
import { WorkloadClientAPI } from "@ms-fabric/workload-client";
import { IncidentItemEditor } from "./items/IncidentItem";
import { ComplianceAssessmentItemEditor } from "./items/ComplianceAssessmentItem";
import { ConditionalPlaygroundRoutes } from "./playground/ConditionalPlaygroundRoutes";

/*
    Add your Item Editor in the Route section of the App function below
*/

interface AppProps {
    history: History;
    workloadClient: WorkloadClientAPI;
}

export interface PageProps {
    workloadClient: WorkloadClientAPI;
    history?: History
}

export interface ContextProps {
    itemObjectId?: string;
    workspaceObjectId?: string
    source?: string;
}

export interface SharedState {
    message: string;
}

export function App({ history, workloadClient }: AppProps) {
    console.log('🎯 App component rendering with history:', history);
    console.log('🎯 Current location:', history.location);

    return <Router history={history}>
        {/* Test route for debugging */}
        <Route exact path="/">
            <div style={{ padding: '20px', backgroundColor: '#f0f0f0' }}>
                <h1>🎉 Workload is running!</h1>
                <p>Current URL: {window.location.href}</p>
                <p>Workload Name: {process.env.WORKLOAD_NAME}</p>
            </div>
        </Route>    
        <Switch>
            {/* Routings for the Incident Item Editor */}
            <Route path="/IncidentItem-editor/:itemObjectId">
                <IncidentItemEditor
                    workloadClient={workloadClient} data-testid="IncidentItem-editor" />
            </Route>

            {/* Routings for the Compliance Assessment Item Editor */}
            <Route path="/ComplianceAssessmentItem-editor/:itemObjectId">
                <ComplianceAssessmentItemEditor
                    workloadClient={workloadClient} data-testid="ComplianceAssessmentItem-editor" />
            </Route>

            {/* Conditionally loaded playground routes (only in development) */}
            <ConditionalPlaygroundRoutes workloadClient={workloadClient} />
        </Switch>
    </Router>;
}