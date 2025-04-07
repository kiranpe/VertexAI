provider "google" {
  project = var.project_id
  region  = var.region
}

data "archive_file" "function_zip" {
  type        = "zip"
  source_dir  = "${path.module}/function"
  output_path = "${path.module}/function.zip"
}

resource "google_storage_bucket" "function_bucket" {
  name     = "${var.project_id}-workbench-cleanup-bucket"
  location = var.region
  force_destroy = true
}

resource "google_storage_bucket_object" "function_archive" {
  name   = "function.zip"
  bucket = google_storage_bucket.function_bucket.name
  source = data.archive_file.function_zip.output_path
}

resource "google_cloudfunctions2_function" "delete_workbench" {
  name        = "delete-workbench"
  location    = var.region
  description = "Deletes TERMINATED Vertex AI Workbench instances"

  build_config {
    runtime     = "python310"
    entry_point = "delete_terminated_workbench_instances"
    source {
      storage_source {
        bucket = google_storage_bucket.function_bucket.name
        object = google_storage_bucket_object.function_archive.name
      }
    }
  }

  service_config {
    available_memory   = "512M"
    timeout_seconds    = 540
    ingress_settings   = "INGRESS_INTERNAL_AND_GCLB"
    max_instance_count = 1
  }

  event_trigger {
    trigger_region = var.region
    event_type     = "google.cloud.scheduler.job.publish"
    retry_policy   = "RETRY_POLICY_DO_NOT_RETRY"
  }
}

resource "google_service_account" "scheduler_sa" {
  account_id   = "scheduler-workbench-sa"
  display_name = "Scheduler to invoke Workbench Cleanup Function"
}

resource "google_cloud_run_service_iam_member" "invoker" {
  service    = google_cloudfunctions2_function.delete_workbench.name
  location   = var.region
  role       = "roles/run.invoker"
  member     = "serviceAccount:${google_service_account.scheduler_sa.email}"
}

resource "google_cloud_scheduler_job" "workbench_cleanup_job" {
  name        = "daily-workbench-cleanup"
  description = "Trigger workbench cleanup at 4PM PST"
  schedule    = "0 16 * * *"
  time_zone   = "America/Los_Angeles"

  http_target {
    uri         = google_cloudfunctions2_function.delete_workbench.service_config[0].uri
    http_method = "POST"

    oidc_token {
      service_account_email = google_service_account.scheduler_sa.email
    }
  }
}