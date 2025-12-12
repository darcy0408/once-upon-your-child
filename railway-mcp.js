#!/usr/bin/env node
// Minimal Railway MCP helper: list services, trigger deploys, fetch logs.
import { readFileSync } from "fs";
import fetch from "node-fetch";

const token = process.env.RAILWAY_TOKEN;
if (!token) {
  throw new Error("RAILWAY_TOKEN env var required");
}

async function gql(query, variables = {}) {
  const res = await fetch("https://backboard.railway.app/graphql/v2", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify({ query, variables }),
  });
  const json = await res.json();
  if (json.errors) throw new Error(JSON.stringify(json.errors));
  return json.data;
}

const input = readFileSync(0, "utf8");
const req = JSON.parse(input);
const { method, params, id } = req;

async function handle() {
  if (method === "initialize") {
    return {
      id,
      result: {
        resources: [],
        resourceTemplates: [],
        actions: [
          { name: "railway.services", description: "List services" },
          { name: "railway.deploy", description: "Trigger deploy for serviceId" },
          { name: "railway.logs", description: "Fetch recent deploy logs" },
        ],
      },
    };
  }

  if (method === "call" && params?.name === "railway.services") {
    const data = await gql(
      `query { me { projects { id name environments { id name services { id name } } } } }`
    );
    return { id, result: data };
  }

  if (method === "call" && params?.name === "railway.deploy") {
    const { serviceId } = params.arguments || {};
    if (!serviceId) throw new Error("serviceId required");
    const data = await gql(
      `mutation($serviceId: String!) { deployService(serviceId: $serviceId, input: {}) { id status } }`,
      { serviceId }
    );
    return { id, result: data };
  }

  if (method === "call" && params?.name === "railway.logs") {
    const { serviceId, limit = 200 } = params.arguments || {};
    if (!serviceId) throw new Error("serviceId required");
    const data = await gql(
      `query($serviceId: String!, $limit: Int) {
         service(id: $serviceId) {
           deployments(last: $limit) {
             edges { node { id status createdAt logs } }
           }
         }
       }`,
      { serviceId, limit }
    );
    return { id, result: data };
  }

  return { id, error: { code: -32601, message: "Method not found" } };
}

handle()
  .then((res) => process.stdout.write(JSON.stringify(res)))
  .catch((err) => {
    const errRes = { id, error: { code: -32000, message: err.message } };
    process.stdout.write(JSON.stringify(errRes));
  });
