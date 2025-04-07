from googleapiclient.discovery import build
from google.cloud import notebooks_v1

def delete_terminated_workbench_instances(request):
    project_id = "mlops-448320"
    label_key = "notebooks-product"
    label_value = "workbench-instances"

    try:
        print(f"🚀 Starting cleanup for project: {project_id}, label: {label_key}: {label_value}")

        compute = build('compute', 'v1')
        instances_to_delete = []

        result = compute.instances().aggregatedList(project=project_id).execute()

        for zone_url, zone_data in result.get('items', {}).items():
            zone = zone_url.split('/')[-1]
            for instance in zone_data.get('instances', []):
                labels = instance.get('labels', {})
                status = instance.get('status')
                if labels.get(label_key) == label_value and status == 'TERMINATED':
                    print(f"📝 Found TERMINATED: {instance['name']} in zone {zone}")
                    instances_to_delete.append((instance['name'], zone))

        if not instances_to_delete:
            message = "✅ No TERMINATED instances found with the specified label."
            print(message)
            return {"message": message}, 200

        client = notebooks_v1.NotebookServiceClient()
        deleted_instances = []

        for instance_name, zone in instances_to_delete:
            full_name = f"projects/{project_id}/locations/{zone}/instances/{instance_name}"
            try:
                print(f"🗑️ Deleting: {full_name}")
                operation = client.delete_instance(name=full_name)
                operation.result(timeout=60)
                print(f"✅ Successfully deleted: {full_name}")
                deleted_instances.append(full_name)
            except Exception as e:
                print(f"⚠️ Failed to delete {full_name}: {str(e)}")

        summary = f"🎉 Deleted {len(deleted_instances)} instance(s)."
        print(summary)
        return {
            "deleted": deleted_instances,
            "count": len(deleted_instances),
            "message": summary
        }, 200

    except Exception as e:
        error_msg = f"❌ Unexpected error: {str(e)}"
        print(error_msg)
        return {"error": error_msg}, 200  # Return 200 to prevent retries
