// https://read.acloud.guru/deploy-a-jenkins-cluster-on-aws-35dcf66a1eca

// https://documentation.red-gate.com/ddfo/drift-detection
// https://www.red-gate.com/hub/product-learning/sql-compare/pre-deploy-migration-scripts
// http://workingwithdevs.com/introducing-flysql-flyway-redgate/
// https://github.com/aboussetta/repo-01.git
// https://github.com/aboussetta/repo-02.git
// https://github.com/aboussetta/repo-03.git
// https://github.com/zeromq/czmq/blob/master/Jenkinsfile
// https://github.com/alisw/docks/blob/master/Jenkinsfile

//http://www.h2database.com/html/features.html
// While you can't use Groovy's .collect or similar methods currently, you can
// still transform a list into a set of actual build steps to be executed in
// parallel.

//#!groovy

pipeline {
    agent any
    triggers {
        pollSCM('* * * * *')
    }

	//environment {
	//}

	//libraries {
	//}

	//options {
	//}

	//parameters {
	//}

	//tools {
	//}
	//logRotator {
  	//	Remove logs after two days
  	//	daysToKeep(2)
	//}
	// using the Timestamper plugin we can add timestamps to the console log
  	//options {
    //	timestamps()
  	//}
    stages {	
        stage('Initiate') {
	        stages {
				stage('Initiate Github Repository Pipelines'){
    	        	steps {
						script{
							def parallelRepos = [:]
							def listRepositories = ["flyway", "repo-01", "repo-02", "repo-03"]
							for (int r = 0; r < listRepositories.size(); r++) {
								def repo = listRepositories[r]
								println(repo)
								parallelRepos["${repo}"] = {
                            		node {
                                		stage("${repo}") {
											//steps{
												println("stage - before checkout ${repo}")
											//}
                                		}
										stage("Checkout ${repo}") {
            								//steps {
                								echo "Run Flyway Github"
												println("git - ${repo}")
												//dir("${repo}") {
    											//	checkout scm
												//}
                								git "https://github.com/aboussetta/flyway.git"
												println(currentBuild.changeSets)
												dir('${repo}') {
    												checkout scm
												}
												// checkout scm
												sh "cd /Users/abderrahim.boussetta/.jenkins/workspace/flyway_pipeline_oracle/${repo}"
												// stash includes: '*.sql', name: 'db'
												println(currentBuild.changeSets) 
												println(currentBuild.changeSets.items)
            								//}
        								}
        								//stage('Create Build Cucumber Reporting') {
										//	steps {
                						//		cucumber buildStatus: "UNSTABLE",
                    					//			fileIncludePattern: "**/cucumber.json",
                    					//			jsonReportDirectory: 'target'
										//	}
										//}
        								stage('Create Build Pipelines') {
            								//steps {
												echo "Cucumber Reporting"
												// Make the output directory.
												//sh "mkdir -p output"
												// Write an useful file, which is needed to be archived.
												//writeFile file: "output/usefulfile.txt", text: "This file is useful, need to archive it."
												// Write an useless file, which is not needed to be archived.
												//writeFile file: "output/uselessfile.md", text: "This file is useless, no need to archive it."
												// 
												//cucumber failedFeaturesNumber: -1, failedScenariosNumber: -1, failedStepsNumber: -1, fileIncludePattern: '**/*.json', pendingStepsNumber: -1, skippedStepsNumber: -1, sortingMethod: 'ALPHABETICAL', undefinedStepsNumber: -1
												echo "Gathering SCM SQL changes Pipelines"
												script{
													def parallelSQLs = [:]
													def changeLogSets = currentBuild.changeSets
													for (int i = 0; i < changeLogSets.size(); i++) {
														def entries = changeLogSets[i].items
														for (int j = 0; j < entries.length; j++) {
															def entry = entries[j]
															echo "${entry.commitId} by ${entry.author} on ${new Date(entry.timestamp)}: ${entry.msg}"
															def files = new ArrayList(entry.affectedFiles)
															for (int k = 0; k < files.size(); k++) {
																def file = files[k]
																echo "hey, ${file.editType.name}, ${file.path}"
																//echo "hey, ${file}"
																//
																// echo 'hey coucou, ${fileBaseName}'
																if (file.path.endsWith(".sql")) {
                        											echo "This a sql script"
																	def filename = file.path
																	fileBaseName = sh 'basename "${filename}"'
																	println(fileBaseName)
																	echo "rahim,  $fileBaseName"
																	script{
																		def fileBaseName = sh([script: 'basename "${filename}"',returnStdout: true]).trim()
																		println(fileBaseName)
																	}
																	echo "rahim,  $fileBaseName"
																	println(fileBaseName)
																	echo "hey, BEFORE parallelSQLs"
																	println("hey, BEFORE parallelSQLs")
																	parallelSQLs["$fileBaseName"] = {
																		echo "I am inside the ParallelSQLs"
																		println("I am inside the ParallelSQLs")
																		node {
																			stage("Deploy SQL script: ${file.path}") {
																				echo '${file.path}'
																				def timestamp = new Date().format('yyyyMMddHHmmssSSS', TimeZone.getTimeZone('GMT'))
																				println("Renaming ${file.name} to ${timestamp}__${file.name}")
																				file.renameTo("$file.parentFile.absolutePath$file.separator${timestamp}__$file.name")
																				stage('Build - DB Migration') {
																					environment {
																							FLYWAY_LOCATIONS='filesystem:/Users/abderrahim.boussetta/.jenkins/workspace/flyway_pipeline_oracle/${repo}'
																							FLYWAY_URL='jdbc:oracle:thin:@//hhdora-scan.dev.hh.perform.local:1521/DV_FLYWAY'
																							FLYWAY_USER='flyway'
																							FLYWAY_PASSWORD='flyway_123'
																							FLYWAY_SCHEMAS='FLYWAY'
																							FLYWAY_PATH='/Users/abderrahim.boussetta/.jenkins/tools/sp.sd.flywayrunner.installation.FlywayInstallation/flyway-5.2.4'
																							FLYWAY_EDITION='enterprise'
																							SQLPLUS_PATH='/Users/abderrahim.boussetta/instantclient_12_2/'
																							SQLPLUS_URL='//hhdora-scan.dev.hh.perform.local:1521/DV_FLYWAY'
																					}
																					when {
																						expression {
																							currentBuild.result == null || currentBuild.result == 'SUCCESS' 
																						}
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
																								// dryRun
																								// def ret_flyway_migrate = sh(script:'java -cp drivers/* org.h2.tools.RunScript -url jdbc:h2:file:$FLYWAY_LOCATIONS -script ${file.path}' , returnStdout: true)
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
																							script {
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
																									def undo_script_name = sh(script: "echo ${ret_undo_script_name} | sed 's/^./U/'", returnStdout:true).trim()
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
																				// Developpement Parallel Pipeline
																				stage('Parallel - Dev Delivery') {
																					when {
																						expression {
																							currentBuild.result == null || currentBuild.result == 'SUCCESS' 
																						}
																					}
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
																								FLYWAY_LOCATIONS='filesystem:/Users/abderrahim.boussetta/.jenkins/workspace/flyway_pipeline_oracle/${repo}'
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
																									script {
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
																										FLYWAY_LOCATIONS='filesystem:/Users/abderrahim.boussetta/.jenkins/workspace/flyway_pipeline_oracle/${repo}'
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
																				// Development Approvals
																				stage('Results - Development') {
																					steps {
																						script {			
																							timeout(time: 1, unit: 'DAYS') {
																								def userInput = input message: 'Approve Delivery on Development or Rollback?'
																							}
																						}
																					}
																				}
																				// Staging Parallel Pipeline Delivery
																				stage('Parallel - Stage Delivery') {
																					failFast true // first to fail abort parallel execution
																					parallel {
																						stage('STA - DB Delivery') {
																								environment {
																								FLYWAY_LOCATIONS='filesystem:/Users/abderrahim.boussetta/.jenkins/workspace/flyway_pipeline_oracle/${repo}'
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
																									FLYWAY_LOCATIONS='filesystem:/Users/abderrahim.boussetta/.jenkins/workspace/flyway_pipeline_oracle/${repo}'
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
																						FLYWAY_LOCATIONS='filesystem:/Users/abderrahim.boussetta/.jenkins/workspace/flyway_pipeline_oracle/${repo}'
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
																		}
																	}
																}
															}
														}
													}
												}
												echo " before parallel parallelSQLs"
												parallel parallelSQLs
												// Archive the build output artifacts.
												unstash 'db'
												archiveArtifacts artifacts: '*.sql', fingerprint: true
												timeout(time: 5, unit: 'DAYS') {
													notifyAwaitApproval approvers: getApprovers(developer),
															message: "Press OK to initiate BUILD ?",
															emailPrompt: "Build ${currentBuild.description} is ready to BUILD."
												}
											//}
										}	
									}
								}
							}
							parallel parallelRepos
						}
					}
				}
			}
		}
	}
	post {
        always {
            echo 'COMPLETED'
        }
        success {
            echo 'DEPLOYMENT SUCCEEDED'
        }
        failure {
            echo 'DEPLOYMENT FAILED'
        }
        unstable {
            echo 'DEPLOYMENT UNSTABLE'
        }
        changed {
            echo 'This will run only if the state of the Pipeline has changed'
            echo 'For example, if the Pipeline was previously failing but is now successful'
        }
    }
}