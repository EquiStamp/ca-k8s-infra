#!/usr/bin/env python3

from flask import Flask, request, jsonify
import logging
from kubernetes import client, config

# TODO: Largely untested. May switch to Falco Talon anyway.

try:
    config.load_incluster_config()
    core_v1_api = client.CoreV1Api()
    networking_v1_api = client.NetworkingV1Api()
    print("Successfully loaded Kubernetes config")
except config.ConfigException as e:
    print(f"Could not configure Kubernetes client: {e}")
    core_v1_api = None


app = Flask(__name__)
logging.basicConfig(level=logging.INFO)

TERMINATE_RULES = {"Malicious Binary Execution", "Sensitive File Access Root"}
IGNORE_RULES = {"Debug Rule Triggered"}


@app.route("/alert", methods=["POST"])
def handle_falco_alert():
    if not request.is_json:
        logging.warning("Received non-JSON request")
        return jsonify({"status": "error", "message": "Request must be JSON"}), 400

    alert = request.get_json()

    rule = alert.get("rule", "")
    priority = alert.get("priority", "")
    output_fields = alert.get("output_fields", {})
    pod_name = output_fields.get("k8s.pod.name")
    namespace = output_fields.get("k8s.ns.name")

    logging.info(f"Received alert: {alert} with priority {priority}")

    if rule in TERMINATE_RULES and pod_name and namespace and core_v1_api:
        try:
            logging.warning(
                f"Terminating pod {namespace}/{pod_name} due to rule: {rule}"
            )
            core_v1_api.delete_namespaced_pod(name=pod_name, namespace=namespace)
            logging.info(
                f"Successfully initiated termination for pod {namespace}/{pod_name}"
            )
        except client.ApiException as e:
            logging.error(f"Failed to delete pod {namespace}/{pod_name}: {e}")
        except Exception as e:
            logging.error(f"An unexpected error occurred during pod deletion: {e}")

    return jsonify({"status": "received"}), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=2801)
