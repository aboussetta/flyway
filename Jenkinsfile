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
				checkout scm
				sh 'cd /Users/abderrahim.boussetta/.jenkins/workspace/flyway_pipeline_oracle'
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
        		input(message: 'Do you want to proceed', id: 'yes', ok: 'yes', submitter: "developer,dba", submitterParameter: "developer,dba")
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

