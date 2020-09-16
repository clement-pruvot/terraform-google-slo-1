/**
 * Copyright 2020 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

provider "google" {
  version = "~> 3.19"
}

provider "google-beta" {
  version = "~> 3.19"
}

locals {
  // Load exporters for pipeline and SLOs
  exporters = yamldecode(templatefile("templates/exporters.yaml",
    {
      stackdriver_host_project_id = var.stackdriver_host_project_id,
      project_id                  = var.project_id,
      pubsub_topic_name           = module.slo-pipeline.pubsub_topic_name
  }))

  // Load all SLO configs in the templates/ folder, replace template variables
  // and merge with SLO exporter config in exporters.yaml.
  slo_configs = [
    for file in fileset(path.module, "/templates/slo_*.yaml") :
    merge(yamldecode(templatefile(file,
      {
        stackdriver_host_project_id = var.stackdriver_host_project_id,
        project_id                  = var.project_id,
      })), {
      exporters = local.exporters.slo
    })
  ]
  slo_config_map = { for config in local.slo_configs : config.slo_description => config }
}

module "slo-pipeline" {
  source     = "../../../modules/slo-generator/slo-export"
  project_id = var.project_id
  region     = var.region
  exporters  = local.exporters.pipeline
}

module "slos" {
  for_each   = local.slo_config_map
  source     = "../../../modules/slo-generator/slo"
  schedule   = var.schedule
  region     = var.region
  project_id = var.project_id
  labels     = var.labels
  config     = each.value
}