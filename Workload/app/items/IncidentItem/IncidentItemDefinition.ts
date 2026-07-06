
/**
 * Definition of an Incident item, stored in Fabric's own item-definition
 * storage. SM's backend sets smIncidentId when it creates this Fabric item
 * (SM discovers incidents from its own monitoring across the client's
 * Synapse/ADF/SQL/Fabric estate and pushes a corresponding Fabric item into
 * the client's tenant - the item is never created by a user in the Fabric
 * portal first). The editor never writes this value; it only reads it, then
 * fetches the real incident data from SM's own API.
 */
export interface IncidentItemDefinition {
  smIncidentId?: string;
}
