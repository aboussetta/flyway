pipeline {
    agent any

    stages {
        stage('Checkout') {
            steps {
                echo 'Run Flyway Github'
                git 'https://github.com/aboussetta/flyway.git'
		checkout scm
                stash includes: '*.sql', name: 'db' 
            }
        }
        stage('Build - DB Migration') {
            environment {
                FLYWAY_URL='jdbc:oracle:thin:@//hhdora-scan.dev.hh.perform.local:1521/DV_FLYWAY'
                FLYWAY_USER='flyway'
                FLYWAY_PASSWORD='flyway_123'
                FLYWAY_SCHEMAS='FLYWAY'
            }
            steps {
                echo 'Run Flyway Migration'
		unstash 'db'
                sh '/Users/abderrahim.boussetta/.jenkins/tools/sp.sd.flywayrunner.installation.FlywayInstallation/flyway_420/flyway -user=$FLYWAY_USER -password=$FLYWAY_PASSWORD -url=$FLYWAY_URL migrate'            }
        }
    }
}

