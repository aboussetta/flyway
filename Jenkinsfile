pipeline {
    agent any
    triggers {
        pollSCM('* * * * *')
    }

    stages {
        stage('Checkout') {
            steps {
                echo 'Run Flyway Github'
                git 'https://github.com/aboussetta/flyway.git'
				println(currentBuild.changeSets) 
				checkout scm
				sh 'cd /Users/abderrahim.boussetta/.jenkins/workspace/flyway_pipeline_oracle'
				stash includes: '*.sql', name: 'db'
				println(currentBuild.changeSets) 
				println(currentBuild.changeSets.items)
            }
        }
        stage('Create Build Outputs Artifacts') {

            steps {
				// Make the output directory.
				//sh "mkdir -p output"

				// Write an useful file, which is needed to be archived.
				//writeFile file: "output/usefulfile.txt", text: "This file is useful, need to archive it."

				// Write an useless file, which is not needed to be archived.
				//writeFile file: "output/uselessfile.md", text: "This file is useless, no need to archive it."
				// 
				cucumber failedFeaturesNumber: -1, failedScenariosNumber: -1, failedStepsNumber: -1, fileIncludePattern: '**/*.json', pendingStepsNumber: -1, skippedStepsNumber: -1, sortingMethod: 'ALPHABETICAL', undefinedStepsNumber: -1
				
				echo "Gathering SCM changes"
				script{
					def changeLogSets = currentBuild.changeSets
					for (int i = 0; i < changeLogSets.size(); i++) {
						def entries = changeLogSets[i].items
						for (int j = 0; j < entries.length; j++) {
							def entry = entries[j]
							echo "${entry.commitId} by ${entry.author} on ${new Date(entry.timestamp)}: ${entry.msg}"
							def files = new ArrayList(entry.affectedFiles)
							for (int k = 0; k < files.size(); k++) {
								def file = files[k]
								echo "  ${file.editType.name} ${file.path}"
								echo "${file.path}"
							}
						}
					}
				}


				// Archive the build output artifacts.
				unstash 'db'
				archiveArtifacts artifacts: '*.sql', fingerprint: true
				timeout(time: 5, unit: 'DAYS') {
          			notifyAwaitApproval approvers: getApprovers(developer),
                              message: "Press OK to initiate TEST deployment?",
                              emailPrompt: "Build ${currentBuild.description} is ready to deploy to TEST."
        		}

            }
        }
        stage('Build - DB Migration') {
            environment {
		            FLYWAY_LOCATIONS='filesystem:/Users/abderrahim.boussetta/.jenkins/workspace/flyway_pipeline_oracle'
                	FLYWAY_URL='jdbc:oracle:thin:@//hhdora-scan.dev.hh.perform.local:1521/DV_FLYWAY'
                	FLYWAY_USER='flyway'
                	FLYWAY_PASSWORD='flyway_123'
                	FLYWAY_SCHEMAS='FLYWAY'
		            FLYWAY_PATH='/Users/abderrahim.boussetta/.jenkins/tools/sp.sd.flywayrunner.installation.FlywayInstallation/flyway-5.2.4'
		            FLYWAY_EDITION='enterprise'
					SQLPLUS_PATH='/Users/abderrahim.boussetta/instantclient_12_2/'
					SQLPLUS_URL='//hhdora-scan.dev.hh.perform.local:1521/DV_FLYWAY'
            }
            steps {
				echo 'Run Flyway Migration - Status Before Rollout'
				script{
					def ret_flyway_migrate = sh(script: '$FLYWAY_PATH/flyway -user=$FLYWAY_USER -password=$FLYWAY_PASSWORD -url=$FLYWAY_URL -locations=$FLYWAY_LOCATIONS info', returnStdout: true)
					println(ret_flyway_migrate)
				}
				echo 'Run Flyway Migration'
				script{
						def ret_flyway_migrate = sh(script: '$FLYWAY_PATH/flyway -user=$FLYWAY_USER -password=$FLYWAY_PASSWORD -url=$FLYWAY_URL -locations=$FLYWAY_LOCATIONS migrate', returnStdout: true)
						println(ret_flyway_migrate)
				}
			}
		post {
            	success {
        		    echo 'The build -  DB Migration was successful!'
		        }
				failure {
					echo 'Run Flyway Migration - Status Before Rollback'
					sh '$FLYWAY_PATH/flyway -user=$FLYWAY_USER -password=$FLYWAY_PASSWORD -url=$FLYWAY_URL -locations=$FLYWAY_LOCATIONS info'
					echo 'Run Flyway Migration - Rollback'
					script{
							try {
								// Fails with non-zero exit if dir1 does not exist
								def ret_undo_script_name = sh(script: "$SQLPLUS_PATH/sqlplus -l -S $FLYWAY_USER/$FLYWAY_PASSWORD@$SQLPLUS_URL < ./retrieve_undo_script_name.sql", returnStdout:true).trim()
								println(ret_undo_script_name)
							} catch (Exception ex) {
								println("Unable to read undo_script_name: ${ex}")
							}

							echo 'SQLPlusRunner running file script'
							//def ret_undo_script_name = sh "$SQLPLUS_PATH/sqlplus -l -S $FLYWAY_USER/$FLYWAY_PASSWORD@$SQLPLUS_URL < ./retrieve_undo_script_name.sql"
							//def ret_flyway_undo = sh(script: '$FLYWAY_PATH/flyway -user=$FLYWAY_USER -password=$FLYWAY_PASSWORD -url=$FLYWAY_URL -locations=$FLYWAY_LOCATIONS undo', returnStdout: true)
							//println(ret_flyway_undo)
							def undo_script_name = sh(script: "echo V10__add_rahim_table_with_error.sql | sed 's/^./U/'", returnStdout:true).trim()
					        //def undo_script_name = sh "echo V10__add_rahim_table_with_error.sql | sed 's/^./U/'"
							println(undo_script_name)

							try {
								// Run rollback script
								def ret_undo_script_output = sh(script: "$SQLPLUS_PATH/sqlplus -l -S $FLYWAY_USER/$FLYWAY_PASSWORD@$SQLPLUS_URL < ./$undo_script_name", returnStdout:true).trim()
								println(ret_undo_script_output)
							} catch (Exception ex) {
								println("Unable to execute undo_script_name: ${ex}")
							}

							echo 'Run Flyway Migration - Status After Rollback'
							def ret_flyway_repair = sh(script: '$FLYWAY_PATH/flyway -user=$FLYWAY_USER -password=$FLYWAY_PASSWORD -url=$FLYWAY_URL -locations=$FLYWAY_LOCATIONS repair', returnStdout: true)
							println(ret_flyway_repair)
							sh '$FLYWAY_PATH/flyway -user=$FLYWAY_USER -password=$FLYWAY_PASSWORD -url=$FLYWAY_URL -locations=$FLYWAY_LOCATIONS info'
                	}	
				}
        }
        }
		stage('BUILD - Code Approval') {
			steps {
				echo 'Building..'
        		input(message: 'Do you want to proceed', id: 'yes', ok: 'yes', submitter: "developer", submitterParameter: "developer")
			}
		}
        stage('Parallel - Dev Delivery') {
            failFast true // first to fail abort parallel execution
            parallel {
				stage('DEVA - DB Delivery') {
					input {
               			message "Should we continue?"
                		ok "Yes, we should."
                		submitter "Developer,DBA"
                		parameters {
                    			string(name: 'PERSON', defaultValue: 'Mr Jenkins', description: 'Who should I say hello to?')
                		}
            		}
		        	environment {
						FLYWAY_LOCATIONS='filesystem:/Users/abderrahim.boussetta/.jenkins/workspace/flyway_pipeline_oracle'
		                FLYWAY_URL='jdbc:oracle:thin:@//hhdora-scan.dev.hh.perform.local:1521/DVA_FLYWAY'
		                FLYWAY_USER='flyway_deva'
		                FLYWAY_PASSWORD='flyway_123'
		                FLYWAY_SCHEMAS='FLYWAY_DEVA'
						FLYWAY_PATH='/Users/abderrahim.boussetta/.jenkins/tools/sp.sd.flywayrunner.installation.FlywayInstallation/flyway-5.2.4'
		            }
		            steps {
		                echo 'Run Flyway Migration - Rollout'
						unstash 'db'
		                sh '$FLYWAY_PATH/flyway -user=$FLYWAY_USER -password=$FLYWAY_PASSWORD -url=$FLYWAY_URL -locations=$FLYWAY_LOCATIONS migrate'
			    	}
				post {
                    failure {
						echo 'Run Flyway Migration - Rollback'
                        sh '$FLYWAY_PATH/flyway -user=$FLYWAY_USER -password=$FLYWAY_PASSWORD -url=$FLYWAY_URL -locations=$FLYWAY_LOCATIONS undo'

						echo 'Run Flyway Migration - Status Before Rollback'
						sh '$FLYWAY_PATH/flyway -user=$FLYWAY_USER -password=$FLYWAY_PASSWORD -url=$FLYWAY_URL -locations=$FLYWAY_LOCATIONS info'
						echo 'Run Flyway Migration - Rollback'
						script{
							try {
								// Fails with non-zero exit if dir1 does not exist
								def ret_undo_script_name = sh(script: "$SQLPLUS_PATH/sqlplus -l -S $FLYWAY_USER/$FLYWAY_PASSWORD@$SQLPLUS_URL < ./retrieve_undo_script_name.sql", returnStdout:true).trim()
								println(ret_undo_script_name)
							} catch (Exception ex) {
								println("Unable to read undo_script_name: ${ex}")
							}

							echo 'SQLPlusRunner running file script'
							//def ret_undo_script_name = sh "$SQLPLUS_PATH/sqlplus -l -S $FLYWAY_USER/$FLYWAY_PASSWORD@$SQLPLUS_URL < ./retrieve_undo_script_name.sql"
							//def ret_flyway_undo = sh(script: '$FLYWAY_PATH/flyway -user=$FLYWAY_USER -password=$FLYWAY_PASSWORD -url=$FLYWAY_URL -locations=$FLYWAY_LOCATIONS undo', returnStdout: true)
							//println(ret_flyway_undo)
							def undo_script_name = sh(script: "echo V10__add_rahim_table_with_error.sql | sed 's/^./U/'", returnStdout:true).trim()
					        //def undo_script_name = sh "echo V10__add_rahim_table_with_error.sql | sed 's/^./U/'"
							println(undo_script_name)

							try {
								// Run rollback script
								def ret_undo_script_output = sh(script: "$SQLPLUS_PATH/sqlplus -l -S $FLYWAY_USER/$FLYWAY_PASSWORD@$SQLPLUS_URL < ./$undo_script_name", returnStdout:true).trim()
								println(ret_undo_script_output)
							} catch (Exception ex) {
								println("Unable to execute undo_script_name: ${ex}")
							}

							echo 'Run Flyway Migration - Status After Rollback'
							def ret_flyway_repair = sh(script: '$FLYWAY_PATH/flyway -user=$FLYWAY_USER -password=$FLYWAY_PASSWORD -url=$FLYWAY_URL -locations=$FLYWAY_LOCATIONS repair', returnStdout: true)
							println(ret_flyway_repair)
							sh '$FLYWAY_PATH/flyway -user=$FLYWAY_USER -password=$FLYWAY_PASSWORD -url=$FLYWAY_URL -locations=$FLYWAY_LOCATIONS info'
                		}	

                    }
                }
		 }
		 stage('DEVB - DB Delivery') {
		            environment {
				        FLYWAY_LOCATIONS='filesystem:/Users/abderrahim.boussetta/.jenkins/workspace/flyway_pipeline_oracle'
		                FLYWAY_URL='jdbc:oracle:thin:@//hhdora-scan.dev.hh.perform.local:1521/DVB_FLYWAY'
		                FLYWAY_USER='flyway_devb'
		                FLYWAY_PASSWORD='flyway_123'
		                FLYWAY_SCHEMAS='FLYWAY_DEVB'
						FLYWAY_PATH='/Users/abderrahim.boussetta/.jenkins/tools/sp.sd.flywayrunner.installation.FlywayInstallation/flyway-5.2.4'
		            }
		            steps {
		                echo 'Run Flyway Migration'
				        unstash 'db'
		                sh '$FLYWAY_PATH/flyway -user=$FLYWAY_USER -password=$FLYWAY_PASSWORD -url=$FLYWAY_URL -locations=$FLYWAY_LOCATIONS migrate'
			    }
				post {
                    failure {
						echo 'Run Flyway Migration - Rollback'
                        sh '$FLYWAY_PATH/flyway -user=$FLYWAY_USER -password=$FLYWAY_PASSWORD -url=$FLYWAY_URL -locations=$FLYWAY_LOCATIONS undo'
                    }
                }
		        }
		    }
		}
	    stage('Results - Development') {
		steps {
                 	script {
                    			timeout(time: 1, unit: 'DAYS') {
                        			def userInput = input message: 'Approve Delivery on Development or Rollback?'
                                }

                		}
		}
   	   }

	stage('Parallel - Stage Delivery') {
            	failFast true // first to fail abort parallel execution
            	parallel {
			stage('STA - DB Delivery') {
		            environment {
					FLYWAY_LOCATIONS='filesystem:/Users/abderrahim.boussetta/.jenkins/workspace/flyway_pipeline_oracle'
					FLYWAY_URL='jdbc:oracle:thin:@//hhdora-scan.dev.hh.perform.local:1521/STA_FLYWAY'
					FLYWAY_USER='flyway_sta'
					FLYWAY_PASSWORD='flyway_123'
					FLYWAY_SCHEMAS='FLYWAY_STA'
					FLYWAY_PATH='/Users/abderrahim.boussetta/.jenkins/tools/sp.sd.flywayrunner.installation.FlywayInstallation/flyway-5.2.4'
		            }
		            steps {
		                echo 'Run Flyway Migration'
				        unstash 'db'
		                sh '$FLYWAY_PATH/flyway -user=$FLYWAY_USER -password=$FLYWAY_PASSWORD -url=$FLYWAY_URL -locations=$FLYWAY_LOCATIONS migrate'
			    }
		        }
		        stage('STB - DB Delivery') {
		            environment {
				        FLYWAY_LOCATIONS='filesystem:/Users/abderrahim.boussetta/.jenkins/workspace/flyway_pipeline_oracle'
		                FLYWAY_URL='jdbc:oracle:thin:@//hhdora-scan.dev.hh.perform.local:1521/STB_FLYWAY'
		                FLYWAY_USER='flyway_stb'
		                FLYWAY_PASSWORD='flyway_123'
		                FLYWAY_SCHEMAS='FLYWAY_STB'
						FLYWAY_PATH='/Users/abderrahim.boussetta/.jenkins/tools/sp.sd.flywayrunner.installation.FlywayInstallation/flyway-5.2.4'
		            }
		            steps {
		                echo 'Run Flyway Migration'
				        unstash 'db'
		                sh '$FLYWAY_PATH/flyway -user=$FLYWAY_USER -password=$FLYWAY_PASSWORD -url=$FLYWAY_URL -locations=$FLYWAY_LOCATIONS migrate'

			    }
		        }
		}
	}
	stage('Results - Staging') {
		steps {
                 	script {
                    			timeout(time: 1, unit: 'DAYS') {
                        			input message: 'Approve Delivery on Staging?'
                    			}
                		}
		}
   	}
    stage('PRODB - DB Deployment') {
        environment {
            FLYWAY_LOCATIONS='filesystem:/Users/abderrahim.boussetta/.jenkins/workspace/flyway_pipeline_oracle'
            FLYWAY_URL='jdbc:oracle:thin:@//hhdora-scan.dev.hh.perform.local:1521/PRD_FLYWAY'
            FLYWAY_USER='flyway_pro'
            FLYWAY_PASSWORD='flyway_123'
            FLYWAY_SCHEMAS='FLYWAY'
			FLYWAY_PATH='/Users/abderrahim.boussetta/.jenkins/tools/sp.sd.flywayrunner.installation.FlywayInstallation/flyway-5.2.4'
        }
        steps {
            echo 'Run Flyway Migration'
            unstash 'db'
            sh '$FLYWAY_PATH/flyway -user=$FLYWAY_USER -password=$FLYWAY_PASSWORD -url=$FLYWAY_URL -locations=$FLYWAY_LOCATIONS migrate'
        }
    }
    stage('Results - Production') {
		steps {
                 	script {
                    			timeout(time: 1, unit: 'DAYS') {
                        			input message: 'Approve Delivery on Production?'
                    			}
                		}
		}
   	}
}
 post {
        always {
            echo 'This will always run'
        }
        success {
            echo 'This will run only if successful'
        }
        failure {
            echo 'This will run only if failed'
        }
        unstable {
            echo 'This will run only if the run was marked as unstable'
        }
        changed {
            echo 'This will run only if the state of the Pipeline has changed'
            echo 'For example, if the Pipeline was previously failing but is now successful'
        }
    }

}

def developmentArtifactVersion = ''
def releasedVersion = ''
// get change log to be send over the mail
@NonCPS
def getChangeString() {
    MAX_MSG_LEN = 100
    def changeString = ""

    echo "Gathering SCM changes"
    def changeLogSets = currentBuild.changeSets
    for (int i = 0; i < changeLogSets.size(); i++) {
        def entries = changeLogSets[i].items
        for (int j = 0; j < entries.length; j++) {
            def entry = entries[j]
            truncated_msg = entry.msg.take(MAX_MSG_LEN)
            changeString += " - ${truncated_msg} [${entry.author}]\n"
        }
    }

    if (!changeString) {
        changeString = " - No new changes"
    }
    return changeString
}

def sendEmail(status) {
    mail(
            to: "$EMAIL_RECIPIENTS",
            subject: "Build $BUILD_NUMBER - " + status + " (${currentBuild.fullDisplayName})",
            body: "Changes:\n " + getChangeString() + "\n\n Check console output at: $BUILD_URL/console" + "\n")
}

def getDevVersion() {
    def gitCommit = sh(returnStdout: true, script: 'git rev-parse HEAD').trim()
    def versionNumber;
    if (gitCommit == null) {
        versionNumber = env.BUILD_NUMBER;
    } else {
        versionNumber = gitCommit.take(8);
    }
    print 'build  versions...'
    print versionNumber
    return versionNumber
}

def getReleaseVersion() {
    def pom = readMavenPom file: 'pom.xml'
    def gitCommit = sh(returnStdout: true, script: 'git rev-parse HEAD').trim()
    def versionNumber;
    if (gitCommit == null) {
        versionNumber = env.BUILD_NUMBER;
    } else {
        versionNumber = gitCommit.take(8);
    }
    return pom.version.replace("-SNAPSHOT", ".${versionNumber}")
}





def getChangeAuthorName() {
    return sh(returnStdout: true, script: "git show -s --pretty=%an").trim()
}

def getChangeAuthorEmail() {
    return sh(returnStdout: true, script: "git show -s --pretty=%ae").trim()
}

def getChangeSet() {
    return sh(returnStdout: true, script: 'git diff-tree --no-commit-id --name-status -r HEAD').trim()
}

def getChangeLog() {
    return sh(returnStdout: true, script: "git log --date=short --pretty=format:'%ad %aN <%ae> %n%n%x09* %s%d%n%b'").trim()
}

def getCurrentBranch () {
    return sh (
            script: 'git rev-parse --abbrev-ref HEAD',
            returnStdout: true
    ).trim()
}

def isPRMergeBuild() {
    return (env.BRANCH_NAME ==~ /^PR-\d+$/)
}

def notifyBuild(String buildStatus = 'STARTED') {
    // build status of null means successful
    buildStatus = buildStatus ?: 'SUCCESS'

    def branchName = getCurrentBranch()
    def shortCommitHash = getShortCommitHash()
    def changeAuthorName = getChangeAuthorName()
    def changeAuthorEmail = getChangeAuthorEmail()
    def changeSet = getChangeSet()
    def changeLog = getChangeLog()

    // Default values
    def colorName = 'RED'
    def colorCode = '#FF0000'
    def subject = "${buildStatus}: '${env.JOB_NAME} [${env.BUILD_NUMBER}]'" + branchName + ", " + shortCommitHash
    def summary = "Started: Name:: ${env.JOB_NAME} \n " +
            "Build Number: ${env.BUILD_NUMBER} \n " +
            "Build URL: ${env.BUILD_URL} \n " +
            "Short Commit Hash: " + shortCommitHash + " \n " +
            "Branch Name: " + branchName + " \n " +
            "Change Author: " + changeAuthorName + " \n " +
            "Change Author Email: " + changeAuthorEmail + " \n " +
            "Change Set: " + changeSet

    if (buildStatus == 'STARTED') {
        color = 'YELLOW'
        colorCode = '#FFFF00'
    } else if (buildStatus == 'SUCCESS') {
        color = 'GREEN'
        colorCode = '#00FF00'
    } else {
        color = 'RED'
        colorCode = '#FF0000'
    }

    // Send notifications
    hipchatSend(color: color, notify: true, message: summary, token: "${env.HIPCHAT_TOKEN}",
        failOnError: true, room: "${env.HIPCHAT_ROOM}", sendAs: 'Jenkins', textFormat: true)
if (buildStatus == 'FAILURE') {
        emailext attachLog: true, body: summary, compressLog: true, recipientProviders: [brokenTestsSuspects(), brokenBuildSuspects(), culprits()], replyTo: 'noreply@yourdomain.com', subject: subject, to: 'mpatel@yourdomain.com'
    }
}


def getRepoURL() {
  sh "git config --get remote.origin.url > .git/remote-url"
  return readFile(".git/remote-url").trim()
}

def getCommitSha() {
  sh "git rev-parse HEAD > .git/current-commit"
  return readFile(".git/current-commit").trim()
}

def updateGithubCommitStatus(build) {
  // workaround https://issues.jenkins-ci.org/browse/JENKINS-38674
  repoUrl = getRepoURL()
  commitSha = getCommitSha()

  step([
    $class: 'GitHubCommitStatusSetter',
    reposSource: [$class: "ManuallyEnteredRepositorySource", url: repoUrl],
    commitShaSource: [$class: "ManuallyEnteredShaSource", sha: commitSha],
    errorHandlers: [[$class: 'ShallowAnyErrorHandler']],
    statusResultSource: [
      $class: 'ConditionalStatusResultSource',
      results: [
        [$class: 'BetterThanOrEqualBuildResult', result: 'SUCCESS', state: 'SUCCESS', message: build.description],
        [$class: 'BetterThanOrEqualBuildResult', result: 'FAILURE', state: 'FAILURE', message: build.description],
        [$class: 'AnyBuildResult', state: 'FAILURE', message: 'Loophole']
      ]
    ]
  ])
}