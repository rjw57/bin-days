workspace {

    model {
        councilXOfficer = person "Council X Officer" "" "Officer"
        councilXInfrastructure = softwareSystem "Council X's Database" "" "Database"
        councilXWebsite = softwareSystem "Council X's Website" "" "Website"
        councilXOfficer -> councilXInfrastructure "Updates"

        councilYOfficer = person "Council Y Officer" "" "Officer"
        councilYInfrastructure = softwareSystem "Council Y's Published Schedule" "" "Website"
        councilYWebsite = softwareSystem "Council Y's Website" "" "Website"
        councilYOfficer -> councilYInfrastructure "Updates"

        councilZOfficer = person "Council Z Officer" "" "Officer"
        councilZInfrastructure = softwareSystem "Council Z's Scheduling system"
        councilZWebsite = softwareSystem "Council Z's Website" "" "Website"
        councilZOfficer -> councilZInfrastructure "Updates"

        councilXResident = person "Council X Resident" "" "Resident"
        councilXResident -> councilXWebsite "Uses"

        councilYResident = person "Council Y Resident" "" "Resident"
        councilYResident -> councilYWebsite "Uses"

        councilZResident = person "Council Z Resident" "" "Resident"
        councilZResident -> councilZWebsite "Uses"

        enterprise "UIS" {
            engineer = person "Engineer" "" "Engineer"

            binDaysSystem = softwareSystem "Bin Days" "" "Us" {
                monitoring = container "Monitoring" "" "" "Google Cloud Platform - Monitoring"
                monitoring -> engineer "Alerts" "" "Failure recovery"

                councilAPI = container "Council API" "Authenticated council-facing API" "Apigee" "Google Cloud Platform - Apigee API Platform"
                monitoring -> councilAPI "Checks for elevated error rate"

                councilXIngest = container "Council X Ingest" {
                    councilXIngestTask = component "Ingest task" "" "Cloud Run" "Google Cloud Platform - Cloud Run"
                    councilXIngestSchedule = component "Schedule" "" "Cloud Scheduler" "Google Cloud Platform - Cloud Scheduler"

                    councilXIngestSchedule -> councilXIngestTask "Invokes"
                    councilXIngestTask -> councilXInfrastructure "Queries"
                    monitoring -> councilXIngestTask "Checks for ingest failure"
                }

                councilYIngest = container "Council Y Ingest" {
                    councilYIngestTask = component "Ingest task" "" "Cloud Run" "Google Cloud Platform - Cloud Run"
                    councilYIngestSchedule = component "Schedule" "" "Cloud Scheduler" "Google Cloud Platform - Cloud Scheduler"

                    councilYIngestSchedule -> councilYIngestTask "Invokes"
                    councilYIngestTask -> councilYInfrastructure "Scrapes"
                    monitoring -> councilYIngestTask "Checks for ingest failure"
                }

                councilZIngest = container "Council Z Ingest" {
                    councilZIngestQueue = component "Ingest queue" "" "Cloud PubSub" "Google Cloud Platform - Cloud PubSub"
                    councilZIngestDLQ = component "Dead-letter queue" "" "Cloud PubSub" "Google Cloud Platform - Cloud PubSub"
                    councilZIngestTask = component "Ingest task" "" "Cloud Run" "Google Cloud Platform - Cloud Run"

                    councilZIngestQueue -> councilZIngestTask "Invokes"
                    councilZIngestQueue -> councilZIngestDLQ "Enqueues failures" "" "Failure recovery"
                    monitoring -> councilZIngestDLQ "Checks for ingest failure"
                    councilZIngestDLQ -> councilZIngestTask "Invokes" "" "Failure recovery"

                    engineer -> councilZIngestDLQ "Process failed Council Z backlog" "" "Failure recovery"
                }

                scheduleStore = container "Schedule store" "Data store and query engine" {
                    ingestQueue = component "Ingest queue" "Queues updates" "Cloud PubSub" "Google Cloud Platform - Cloud PubSub"
                    dlq = component "Dead-letter queue" "Records failed updates" "Cloud PubSub" "Google Cloud Platform - Cloud PubSub"

                    ingestTask = component "Ingest task" "Performs idempotent schedule updates in database" "Cloud Run" "Google Cloud Platform - Cloud Run"

                    database = component "Database" "" "Cloud SQL" "Google Cloud Platform - Cloud SQL, Database"
                    alembic = component "Migration tool" "Database schema management and migration" "Alembic" "Offline tool"
                    alembic -> database "Manages schema of"

                    updateQueue = component "Update publisher" "Publishes updated primary keys" "Cloud PubSub" "Google Cloud Platform - Cloud PubSub"

                    monitoring -> dlq "Monitors failed ingest"
                    ingestQueue -> dlq "Enqueues failures" "" "Failure recovery"
                    ingestQueue -> ingestTask "Invokes"
                    ingestTask -> database "Upserts schedules"
                    dlq -> ingestTask "Invokes" "" "Failure recovery"
                    database -> updateQueue "Notifies updated row primary keys"

                    engineer -> dlq "Process failed update backlog" "" "Failure recovery"
                    engineer -> alembic "Performs schema migration via"
                }

                staticPublisher = container "Schedule document store" {
                    updateTask = component "Update task" "Formats schedules as JSON documents" "Cloud Run" "Google Cloud Platform - Cloud Run"
                    publishBucket = component "Published schedules" "" "Cloud Storage" "Google Cloud Platform - Cloud Storage"
                    publishEndpoint = component "CDN and firewall" "" "Cloud Load Balancing" "Google Cloud Platform - Cloud Load Balancing"
                    metricsDatabase = component "Metrics Database" "" "" "Database"

                    updateQueue -> updateTask "Triggers passing updated row(s)"
                    updateTask -> database "Queries"
                    updateTask -> publishBucket "Uploads JSON documents to"
                    publishEndpoint -> publishBucket "Fetches JSON documents from"
                    publishEndpoint -> metricsDatabase "Updates"
                }

                residentSite = container "Query UI" "" "IFrame" "Website"
                residentSite -> publishEndpoint "Fetches JSON documents from"

                councilZInfrastructure -> councilAPI "Pushes new schedules"
                councilAPI -> councilZIngestQueue "Enqueues schedules"
                councilXIngestTask -> ingestQueue "Enqueues schedules"
                councilYIngestTask -> ingestQueue "Enqueues schedules"
                councilZIngestTask -> ingestQueue "Enqueues schedules"
            }
        }

        councilXWebsite -> residentSite "Embeds UI from"
        councilYWebsite -> residentSite "Embeds UI from"
        councilZWebsite -> residentSite "Embeds UI from"
    }

    views {
        systemLandscape "landscape" "System Landscape" {
            include *
            exclude engineer
        }

        container binDaysSystem "system" "Bin Days System" {
            include *
            exclude engineer monitoring
        }

        component councilXIngest "councilXIngest" "Council X Ingest" {
            include * engineer
            exclude engineer->scheduleStore
            exclude monitoring->scheduleStore
        }

        component councilYIngest "councilYIngest" "Council Y Ingest" {
            include * engineer
            exclude engineer->scheduleStore
            exclude monitoring->scheduleStore
        }

        component councilZIngest "councilZIngest" "Council Z Ingest" {
            include * engineer councilZInfrastructure
            exclude engineer->scheduleStore
            exclude monitoring->councilAPI
            exclude monitoring->scheduleStore
        }

        component scheduleStore "scheduleStore" "Schedule Store" {
            include * engineer
            exclude engineer->councilXIngest
            exclude engineer->councilYIngest
            exclude engineer->councilZIngest
            exclude monitoring->councilXIngest
            exclude monitoring->councilYIngest
            exclude monitoring->councilZIngest
        }

        component staticPublisher "staticPublisher" "Static Publication" {
            include *
        }

        themes https://static.structurizr.com/themes/google-cloud-platform-v1.5/theme.json

        styles {
            element "Us" {
                background #85B09A
                colour white
            }

            element "Officer" {
                background darkgreen
            }

            element "Resident" {
                background darkblue
            }

            element "Element" {
                colour black
                background lightgrey
            }

            element "Person" {
                colour white
                background darkblue
                shape Person
            }

            element "Database" {
                shape Cylinder
            }

            element "Website" {
                shape WebBrowser
            }

            relationship "Failure recovery" {
                colour lightcoral
            }
        }
    }

}

// vim:filetype=structurizr:sw=4:sts=4:et
