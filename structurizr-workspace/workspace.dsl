workspace {

    model {
        group "Walmington-on-Sea Council" {
            councilWOfficer = person "Walmington-on-Sea Officer" "" "Officer"
            councilWInfrastructure = softwareSystem "Walmington-on-Sea Schedule API" "" "Infrastructure"
            councilWWebsite = softwareSystem "Walmington-on-Sea Website" "" "Website"
            councilWOfficer -> councilWInfrastructure "Updates"

            councilWTracker = softwareSystem "Walmington-on-Sea Lorry Tracking System" "" "Tracking"
            councilWLorry = element "Bin Lorry" "" "" "Tracking"
            councilWLorry -> councilWTracker "Sends location"
        }

        councilWResident = person "Walmington-on-Sea Council Resident" "" "Resident"
        councilWResident -> councilWWebsite "Uses"

        group "Borsetshire Council" {
            councilXOfficer = person "Borsetshire Officer" "" "Officer"
            councilXInfrastructure = softwareSystem "Borsetshire Schedule Database" "" "Database, Infrastructure"
            councilXWebsite = softwareSystem "Borsetshire Website" "" "Website"
            councilXOfficer -> councilXInfrastructure "Updates"
        }

        councilXResident = person "Borsetshire Council Resident" "" "Resident"
        councilXResident -> councilXWebsite "Uses"

        group "Scarfolk Council" {
            councilYOfficer = person "Scarfolk Officer" "" "Officer"
            councilYInfrastructure = softwareSystem "Scarfolk iCal Endpoint" "" "Website, Infrastructure"
            councilYWebsite = softwareSystem "Scarfolk Website" "" "Website"
            councilYOfficer -> councilYInfrastructure "Updates"
        }

        councilYResident = person "Scarfolk Council Resident" "" "Resident"
        councilYResident -> councilYWebsite "Uses"

        group "Royston Vasey" {
            councilZOfficer = person "Royston Vasey Officer" "" "Officer"
            councilZInfrastructure = softwareSystem "Royston Vasey CSV Endpoint" "" "Website, Infrastructure"
            councilZWebsite = softwareSystem "Royston Vasey Website" "" "Website"
            councilZOfficer -> councilZInfrastructure "Updates"
        }

        councilZResident = person "Royston Vasey Resident" "" "Resident"
        councilZResident -> councilZWebsite "Uses"

        enterprise "UIS" {
            engineer = person "Engineer" "" "Engineer"

            monitoring = softwareSystem "Monitoring" "Google Cloud Platform Monitoring" "Google Cloud Platform - Monitoring"
            monitoring -> engineer "Alerts" "" "Failure recovery"

            scheduleSystem = softwareSystem "Schedule System" "" "Us" {
                councilWIngest = container "Walmington-on-Sea Council Schedule Ingest" {
                    councilWIngestTask = component "Ingest task" "" "Cloud Run" "Google Cloud Platform - Cloud Run"
                    councilWIngestSchedule = component "Schedule" "" "Cloud Scheduler" "Google Cloud Platform - Cloud Scheduler"

                    councilWIngestSchedule -> councilWIngestTask "Invokes"
                    councilWIngestTask -> councilWInfrastructure "Queries"
                    monitoring -> councilWIngestTask "Checks for ingest failure"
                }

                councilXIngest = container "Borsetshire Council Schedule Ingest" {
                    councilXIngestTask = component "Ingest task" "" "Cloud Run" "Google Cloud Platform - Cloud Run"
                    councilXIngestSchedule = component "Schedule" "" "Cloud Scheduler" "Google Cloud Platform - Cloud Scheduler"

                    councilXIngestSchedule -> councilXIngestTask "Invokes"
                    councilXIngestTask -> councilXInfrastructure "Queries"
                    monitoring -> councilXIngestTask "Checks for ingest failure"
                }

                councilYIngest = container "Scarfolk Council Schedule Ingest" {
                    councilYIngestTask = component "Ingest task" "" "Cloud Run" "Google Cloud Platform - Cloud Run"
                    councilYIngestSchedule = component "Schedule" "" "Cloud Scheduler" "Google Cloud Platform - Cloud Scheduler"

                    councilYIngestSchedule -> councilYIngestTask "Invokes"
                    councilYIngestTask -> councilYInfrastructure "Fetches iCal Schedule"
                    monitoring -> councilYIngestTask "Checks for ingest failure"
                }

                councilZIngest = container "Royston Vasey Schedule Ingest" {
                    councilZIngestTask = component "Ingest task" "" "Cloud Run" "Google Cloud Platform - Cloud Run"
                    councilZIngestSchedule = component "Schedule" "" "Cloud Scheduler" "Google Cloud Platform - Cloud Scheduler"

                    councilZIngestSchedule -> councilZIngestTask "Invokes"
                    councilZIngestTask -> councilZInfrastructure "Fetches CSV Schedule"
                    monitoring -> councilZIngestTask "Checks for ingest failure"
                }

                scheduleStore = container "Schedule store" "Data store and query engine" {
                    ingestQueue = component "Ingest queue" "Queues updates" "Cloud PubSub" "Google Cloud Platform - Cloud PubSub"
                    dlq = component "Dead-letter queue" "Records failed updates" "Cloud PubSub" "Google Cloud Platform - Cloud PubSub"

                    ingestTask = component "Ingest task" "Performs idempotent schedule updates in database" "Cloud Run" "Google Cloud Platform - Cloud Run"

                    database = component "Database" "" "Cloud SQL" "Google Cloud Platform - Cloud SQL, Database"
                    alembic = component "Migration tool" "Database schema management and migration" "Alembic" "Offline tool"
                    alembic -> database "Manages schema of"

                    updateQueue = component "Schedule publisher" "Publishes updated primary keys" "Cloud PubSub" "Google Cloud Platform - Cloud PubSub"

                    monitoring -> dlq "Monitors failed ingest"
                    ingestQueue -> dlq "Enqueues failures" "" "Failure recovery"
                    ingestQueue -> ingestTask "Invokes"
                    ingestTask -> database "Upserts schedules"
                    dlq -> ingestTask "Invokes" "" "Failure recovery"
                    database -> updateQueue "Notifies updated schedule primary keys"

                    engineer -> dlq "Process failed update backlog" "" "Failure recovery"
                    engineer -> alembic "Performs schema migration via"
                }

                staticPublisher = container "Static schedule document store" {
                    updateTask = component "Update task" "Formats schedules as JSON documents" "Cloud Run" "Google Cloud Platform - Cloud Run"
                    publishBucket = component "Published schedules" "" "Cloud Storage" "Google Cloud Platform - Cloud Storage"
                    publishEndpoint = component "CDN and firewall" "" "Cloud Load Balancing" "Google Cloud Platform - Cloud Load Balancing"
                    metricsDatabase = component "Metrics Database" "" "" "Database"

                    updateQueue -> updateTask "Notifies updated schedule primary key(s)"
                    updateTask -> database "Queries data for schedule documents"
                    updateTask -> publishBucket "Uploads JSON documents to"
                    publishEndpoint -> publishBucket "Fetches JSON documents from"
                    publishEndpoint -> metricsDatabase "Updates"

                    monitoring -> publishEndpoint "Monitors elevated error rate"
                }

                residentSite = container "Query UI" "" "IFrame" "Website"
                residentSite -> publishEndpoint "Fetches JSON documents from"

                councilWIngestTask -> ingestQueue "Enqueues schedules"
                councilXIngestTask -> ingestQueue "Enqueues schedules"
                councilYIngestTask -> ingestQueue "Enqueues schedules"
                councilZIngestTask -> ingestQueue "Enqueues schedules"
            }

            trackingSystem = softwareSystem "Tracking System" "" "Us" {
                trackingStore = container "Tracking store" "Data store and query engine" "" "Tracking" {
                    trackingIngestTask = component "Ingest task" "Processes new locations" "Cloud Run" "Google Cloud Platform - Cloud Run"
                    trackerQueue = component "Tracker publisher" "Publishes newly received locations" "Cloud PubSub" "Google Cloud Platform - Cloud PubSub"

                    trackingDatabase = component "Database" "Stores Recent Lorry Locations" "Cloud SQL" "Google Cloud Platform - Cloud SQL, Database"
                    trackingAlembic = component "Migration tool" "Database schema management and migration" "Alembic" "Offline tool"
                    trackingAlembic -> trackingDatabase "Manages schema of"

                    trackingIngestTask -> trackerQueue "Pushes most recent location"
                    trackingIngestTask -> trackingDatabase "Upserts most recent location"

                    engineer -> trackingAlembic "Performs schema migration via"
                    monitoring -> trackingIngestTask "Monitor elevated failure rate"
                }

                trackingIngestAPI = container "Tracking Ingest API" {
                    realTimeEndpoint = component "Council-facing Tracking API" "" "Apigee" "Google Cloud Platform - Apigee API Platform"
                    monitoring -> realTimeEndpoint "Monitors for elevated errors"
                }

                realTimeEndpoint -> trackingIngestTask "Sends new location"

                trackingQueryAPI = container "Tracking Query API" {
                    trackingQueryHTTPS = component "HTTP Current Status Endpoint Handler" "" "Cloud Run" "Google Cloud Platform - Cloud Run"
                    trackingQueryWS = component "WebSocket Realtime Update Endpoint Handler" "" "Cloud Run" "Google Cloud Platform - Cloud Run"

                    trackingQueryHTTPS -> trackingDatabase "Queries most recent locations"
                    trackingQueryWS -> trackerQueue "Subscribes to filtered updates from"

                    monitoring -> trackingQueryHTTPS "Monitors for elevated errors"
                    monitoring -> trackingQueryWS "Monitors for elevated errors"
                }

                trackingSite = container "Tracking UI" "" "IFrame" "Website,Tracking"
                trackingSite -> trackingQueryHTTPS "Fetches bootstrap locations"
                trackingQueryWS -> trackingSite "Pushes location updates"
            }
        }

        councilWTracker -> realTimeEndpoint "Sends lorry locations"

        councilWWebsite -> residentSite "Embeds Schedule UI from"
        councilXWebsite -> residentSite "Embeds Schedule UI from"
        councilYWebsite -> residentSite "Embeds Schedule UI from"
        councilZWebsite -> residentSite "Embeds Schedule UI from"

        councilWWebsite -> trackingSite "Embeds Tracking UI from"
    }

    views {
        systemLandscape "ingestLandscape" "System Landscape: Council" {
            include *
            exclude engineer councilWWebsite councilXWebsite councilYWebsite councilZWebsite element.tag==Resident monitoring
        }

        systemLandscape "residentLandscape" "System Landscape: Resident" {
            include *
            exclude engineer element.tag==Officer element.tag==Infrastructure element.tag==Tracking monitoring
        }

        container scheduleSystem "scheduleSystem" "Bin Day Schedules System" {
            include *
            exclude engineer monitoring
        }

        component councilWIngest "councilWIngest" "Walmington-on-Sea Ingest" {
            include * engineer
            exclude engineer->scheduleStore
            exclude monitoring->scheduleStore
            autoLayout tb
        }

        component councilXIngest "councilXIngest" "Borsetshire Ingest" {
            include * engineer
            exclude engineer->scheduleStore
            exclude monitoring->scheduleStore
            autoLayout tb
        }

        component councilYIngest "councilYIngest" "Scarfolk Ingest" {
            include * engineer
            exclude engineer->scheduleStore
            exclude monitoring->scheduleStore
            autoLayout tb
        }

        component councilZIngest "councilZIngest" "Royston Vasey Ingest" {
            include * engineer councilZInfrastructure
            exclude engineer->scheduleStore
            exclude monitoring->scheduleStore
            autoLayout tb
        }

        component scheduleStore "scheduleStore" {
            include * engineer
            exclude engineer->councilWIngest
            exclude engineer->councilXIngest
            exclude engineer->councilYIngest
            exclude engineer->councilZIngest
            exclude monitoring->councilWIngest
            exclude monitoring->councilXIngest
            exclude monitoring->councilYIngest
            exclude monitoring->councilZIngest
            exclude monitoring->staticPublisher
        }

        container trackingSystem "trackingSystem" {
            include *
            exclude engineer monitoring
        }

        component trackingIngestAPI "trackingIngestAPI" {
            include * engineer
            exclude engineer->trackingStore
            exclude monitoring->trackingStore
        }

        component trackingQueryAPI "trackingQueryAPI" {
            include * engineer
            exclude engineer->trackingStore
            exclude monitoring->trackingStore
        }

        component trackingStore "trackingStore" {
            include * engineer
            exclude engineer->trackingIngestAPI
            exclude engineer->councilWIngest
            exclude engineer->councilXIngest
            exclude engineer->councilYIngest
            exclude engineer->councilZIngest
            exclude monitoring->trackingIngestAPI
            exclude monitoring->councilWIngest
            exclude monitoring->councilXIngest
            exclude monitoring->councilYIngest
            exclude monitoring->councilZIngest
            exclude monitoring->trackingQueryAPI
        }

        component staticPublisher "staticPublisher" {
            include * engineer
            exclude engineer->scheduleStore
            exclude monitoring->scheduleStore
        }

        themes https://static.structurizr.com/themes/google-cloud-platform-v1.5/theme.json

        styles {
            element "Us" {
                background #85B09A
                colour white
            }

            element "Officer" {
                background darkblue
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
