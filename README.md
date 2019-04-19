# flyway
Well done Rahim what I have seen so far I do like it ! Next steps we play around with the POC
 
Below are my suggestions regarding the CICD
 
Before the developer script is apply to the development database DBA’s are able to review the scripts update + rollback and be able to send it back to the developer if we have any issues
We apply the script the script and output is displayed
DBA applies the script – successfully confirmation sent to developer – if script fails rollback script is run and developer is sent output of the error and notification to fix their script
We only proceed onto to staging once confirmation is received back from the developer
DBA applies the script – successfully confirmation sent to developer with output  – if script fails rollback script is run and developer is sent with output of the error and notification to fix their script
We only proceed onto to Production  once confirmation is received back from the developer
 
Also bear in mind that developers may wait up to weeks in staging or dev before they go to production.



# flyway

https://medium.com/@maxy_ermayank/pipeline-as-a-code-using-jenkins-2-aa872c6ecdce

    def changeSet = script.currentBuild.changeSets[0];
    Set authors = [];
    if (changeSet != null) {
        for (change in changeSet.items) {
            authors.add(change.author.fullName)
        }
    }

    def author = ""
def changeSet = currentBuild.rawBuild.changeSets               
for (int i = 0; i < changeSet.size(); i++) 
{
   def entries = changeSet[i].items;
   for (int i = 0; i < changeSet.size(); i++) 
            {
                       def entries = changeSet[i].items;
                       def entry = entries[0]
                       author += "${entry.author}"
            } 
 }
 print author;




	#!groovy
2	
3	//===========================================================================================================
4	// Main loop of the compilation
5	//===========================================================================================================
6	node ('master'){
7	
8	        // Globals
9	        BuildDir  = pwd tmp: true
10	        SrcDir    = pwd tmp: false
11	        Settings  = null
12	        StageName = ''
13	
14	        // Local variables
15	        def err = null
16	        def log_needed = false
17	
18	        currentBuild.result = "SUCCESS"
19	
20	        try {
21	                //Wrap build to add timestamp to command line
22	                wrap([$class: 'TimestamperBuildWrapper']) {
23	
24	                        notify_server(0)
25	
26	                        Settings = prepare_build()
27	
28	                        clean()
29	
30	                        checkout()
31	
32	                        notify_server(0)
33	
34	                        build()
35	
36	                        test()
37	
38	                        benchmark()
39	
40	                        build_doc()
41	
42	                        publish()
43	
44	                        notify_server(45)
45	                }
46	        }
47	
48	        //If an exception is caught we need to change the status and remember to
49	        //attach the build log to the email
50	        catch (Exception caughtError) {
51	                //rethrow error later
52	                err = caughtError
53	
54	                echo err.toString()
55	
56	                //An error has occured, the build log is relevent
57	                log_needed = true
58	
59	                //Store the result of the build log
60	                currentBuild.result = "${StageName} FAILURE".trim()
61	        }
62	
63	        finally {
64	                //Send email with final results if this is not a full build
65	                if( Settings && !Settings.Silent ) {
66	                        email(log_needed, Settings.IsSandbox)
67	                }
68	
69	                echo 'Build Completed'
70	
71	                /* Must re-throw exception to propagate error */
72	                if (err) {
73	                        throw err
74	                }
75	        }
76	}
77	
78	//===========================================================================================================
79	// Main compilation routines
80	//===========================================================================================================
81	def clean() {
82	        build_stage('Cleanup') {
83	                // clean the build by wipping the build directory
84	                dir(BuildDir) {
85	                        deleteDir()
86	                }
87	        }
88	}
89	
90	//Compilation script is done here but environnement set-up and error handling is done in main loop
91	def checkout() {
92	        build_stage('Checkout') {
93	                //checkout the source code and clean the repo
94	                final scmVars = checkout scm
95	                Settings.GitNewRef = scmVars.GIT_COMMIT
96	                Settings.GitOldRef = scmVars.GIT_PREVIOUS_COMMIT
97	
98	                echo GitLogMessage()
99	        }
100	}
101	
102	def build() {
103	        build_stage('Build') {
104	                // Build outside of the src tree to ease cleaning
105	                dir (BuildDir) {
106	                        //Configure the conpilation (Output is not relevant)
107	                        //Use the current directory as the installation target so nothing escapes the sandbox
108	                        //Also specify the compiler by hand
109	                        targets=""
110	                        if( Settings.RunAllTests ) {
111	                                targets="--with-target-hosts='host:debug,host:nodebug'"
112	                        } else {
113	                                targets="--with-target-hosts='host:debug'"
114	                        }
115	
116	                        sh "${SrcDir}/configure CXX=${Settings.Compiler.cpp_cc} ${Settings.Architecture.flags} ${targets} --with-backend-compiler=${Settings.Compiler.cfa_cc} --quiet"
117	
118	                        //Compile the project
119	                        sh 'make -j 8 --no-print-directory'
120	                }
121	        }
122	}
123	
124	def test() {
125	        build_stage('Test') {
126	
127	                dir (BuildDir) {
128	                        //Run the tests from the tests directory
129	                        if ( Settings.RunAllTests ) {
130	                                sh 'make --no-print-directory -C tests all-tests debug=yes'
131	                                sh 'make --no-print-directory -C tests all-tests debug=no '
132	                        }
133	                        else {
134	                                sh 'make --no-print-directory -C tests'
135	                        }
136	                }
137	        }
138	}
139	
140	def benchmark() {
141	        build_stage('Benchmark') {
142	
143	                if( !Settings.RunBenchmark ) return
144	
145	                dir (BuildDir) {
146	                        //Append bench results
147	                        sh "make --no-print-directory -C benchmark jenkins githash=${gitRefNewValue} arch=${Settings.Architecture} | tee ${SrcDir}/bench.json"
148	                }
149	        }
150	}
151	
152	def build_doc() {
153	        build_stage('Documentation') {
154	
155	                if( !Settings.BuildDocumentation ) return
156	
157	                dir ('doc/user') {
158	                        make_doc()
159	                }
160	
161	                dir ('doc/refrat') {
162	                        make_doc()
163	                }
164	        }
165	}
166	
167	def publish() {
168	        build_stage('Publish') {
169	
170	                if( !Settings.Publish ) return
171	
172	                //Then publish the results
173	                sh 'curl --silent --show-error -H \'Content-Type: application/json\' --data @bench.json https://cforall.uwaterloo.ca:8082/jenkins/publish > /dev/null || true'
174	        }
175	}
176	
177	//===========================================================================================================
178	//Routine responsible of sending the email notification once the build is completed
179	//===========================================================================================================
180	def gitUpdate(String gitRefOldValue, String gitRefNewValue) {
181	        def update = ""
182	        sh "git rev-list ${gitRefOldValue}..${gitRefNewValue} > GIT_LOG";
183	        readFile('GIT_LOG').eachLine { rev ->
184	                sh "git cat-file -t ${rev} > GIT_TYPE"
185	                def type = readFile('GIT_TYPE')
186	
187	                update += "       via  ${rev} (${type})\n"
188	        }
189	        def rev = gitRefOldValue
190	        sh "git cat-file -t ${rev} > GIT_TYPE"
191	        def type = readFile('GIT_TYPE')
192	
193	        update += "      from  ${rev} (${type})\n"
194	        return update
195	}
196	
197	def gitLog(String gitRefOldValue, String gitRefNewValue) {
198	        sh "git rev-list --format=short ${oldRef}...${newRef} > ${BuildDir}/GIT_LOG"
199	        return readFile("${BuildDir}/GIT_LOG")
200	}
201	
202	def gitDiff(String gitRefOldValue, String gitRefNewValue) {
203	        sh "git diff --stat ${newRef} ${oldRef} > ${BuildDir}/GIT_DIFF"
204	        return readFile("${BuildDir}/GIT_DIFF")
205	}
206	
207	def GitLogMessage() {
208	        if (!Settings || !Settings.GitOldRef || !Settings.GitNewRef) return "\nERROR retrieveing git information!\n"
209	
210	        return """
211	The branch ${env.BRANCH_NAME} has been updated.
212	${gitUpdate(Settings.GitOldRef, Settings.GitNewRef)}
213	
214	Check console output at ${env.BUILD_URL} to view the results.
215	
216	- Status --------------------------------------------------------------
217	
218	BUILD# ${env.BUILD_NUMBER} - ${currentBuild.result}
219	
220	- Log -----------------------------------------------------------------
221	${gitLog(Settings.GitOldRef, Settings.GitNewRef)}
222	-----------------------------------------------------------------------
223	Summary of changes:
224	${gitDiff(Settings.GitOldRef, Settings.GitNewRef)}
225	"""
226	}
227	
228	//Standard build email notification
229	def email(boolean log, boolean bIsSandbox) {
230	        //Since tokenizer doesn't work, figure stuff out from the environnement variables and command line
231	        //Configurations for email format
232	        echo 'Notifying users of result'
233	
234	        def project_name = (env.JOB_NAME =~ /(.+)\/.+/)[0][1].toLowerCase()
235	        def email_subject = "[${project_name} git][BUILD# ${env.BUILD_NUMBER} - ${currentBuild.result}] - branch ${env.BRANCH_NAME}"
236	        def email_body = """This is an automated email from the Jenkins build machine. It was
237	generated because of a git hooks/post-receive script following
238	a ref change which was pushed to the Cforall repository.
239	""" + GitLogMessage()
240	
241	        def email_to = "cforall@lists.uwaterloo.ca"
242	
243	        if( Settings && !Settings.IsSandbox ) {
244	                //send email notification
245	                emailext body: email_body, subject: email_subject, to: email_to, attachLog: log
246	        } else {
247	                echo "Would send email to: ${email_to}"
248	                echo "With title: ${email_subject}"
249	                echo "Content: \n${email_body}"
250	        }
251	}
252	
253	//===========================================================================================================
254	// Helper classes/variables/routines
255	//===========================================================================================================
256	//Description of a compiler (Must be serializable since pipelines are persistent)
257	class CC_Desc implements Serializable {
258	        public String cc_name
259	        public String cpp_cc
260	        public String cfa_cc
261	
262	        CC_Desc(String cc_name, String cpp_cc, String cfa_cc) {
263	                this.cc_name = cc_name
264	                this.cpp_cc = cpp_cc
265	                this.cfa_cc = cfa_cc
266	        }
267	}
268	
269	//Description of an architecture (Must be serializable since pipelines are persistent)
270	class Arch_Desc implements Serializable {
271	        public String name
272	        public String flags
273	
274	        Arch_Desc(String name, String flags) {
275	                this.name  = name
276	                this.flags = flags
277	        }
278	}
279	
280	class BuildSettings implements Serializable {
281	        public final CC_Desc Compiler
282	        public final Arch_Desc Architecture
283	        public final Boolean RunAllTests
284	        public final Boolean RunBenchmark
285	        public final Boolean BuildDocumentation
286	        public final Boolean Publish
287	        public final Boolean Silent
288	        public final Boolean IsSandbox
289	        public final String DescLong
290	        public final String DescShort
291	
292	        public String GitNewRef
293	        public String GitOldRef
294	
295	        BuildSettings(java.util.Collections$UnmodifiableMap param, String branch) {
296	                switch( param.Compiler ) {
297	                        case 'gcc-6':
298	                                this.Compiler = new CC_Desc('gcc-6', 'g++-6', 'gcc-6')
299	                        break
300	                        case 'gcc-5':
301	                                this.Compiler = new CC_Desc('gcc-5', 'g++-5', 'gcc-5')
302	                        break
303	                        case 'gcc-4.9':
304	                                this.Compiler = new CC_Desc('gcc-4.9', 'g++-4.9', 'gcc-4.9')
305	                        break
306	                        case 'clang':
307	                                this.Compiler = new CC_Desc('clang', 'clang++', 'gcc-6')
308	                        break
309	                        default :
310	                                error "Unhandled compiler : ${cc}"
311	                }
312	
313	                switch( param.Architecture ) {
314	                        case 'x64':
315	                                this.Architecture = new Arch_Desc('x64', '--host=x86_64')
316	                        break
317	                        case 'x86':
318	                                this.Architecture = new Arch_Desc('x86', '--host=i386')
319	                        break
320	                        default :
321	                                error "Unhandled architecture : ${arch}"
322	                }
323	
324	                this.RunAllTests        = param.RunAllTests
325	                this.RunBenchmark       = param.RunBenchmark
326	                this.BuildDocumentation = param.BuildDocumentation
327	                this.Publish            = param.Publish
328	                this.Silent             = param.Silent
329	                this.IsSandbox          = (branch == "jenkins-sandbox")
330	
331	                def full = param.RunAllTests ? " (Full)" : ""
332	                this.DescShort = "${ this.Compiler.cc_name }:${ this.Architecture.name }${full}"
333	
334	                this.DescLong = """Compiler              : ${ this.Compiler.cc_name } (${ this.Compiler.cpp_cc }/${ this.Compiler.cfa_cc })
335	Architecture            : ${ this.Architecture.name }
336	Arc Flags               : ${ this.Architecture.flags }
337	Run All Tests           : ${ this.RunAllTests.toString() }
338	Run Benchmark           : ${ this.RunBenchmark.toString() }
339	Build Documentation     : ${ this.BuildDocumentation.toString() }
340	Publish                 : ${ this.Publish.toString() }
341	Silent                  : ${ this.Silent.toString() }
342	"""
343	
344	                this.GitNewRef = ''
345	                this.GitOldRef = ''
346	        }
347	}
348	
349	def prepare_build() {
350	        // prepare the properties
351	        properties ([                                                                                                   \
352	                [$class: 'ParametersDefinitionProperty',                                                                \
353	                        parameterDefinitions: [                                                                         \
354	                                [$class: 'ChoiceParameterDefinition',                                           \
355	                                        description: 'Which compiler to use',                                   \
356	                                        name: 'Compiler',                                                                       \
357	                                        choices: 'gcc-6\ngcc-5\ngcc-4.9\nclang',                                        \
358	                                        defaultValue: 'gcc-6',                                                          \
359	                                ],                                                                                              \
360	                                [$class: 'ChoiceParameterDefinition',                                           \
361	                                        description: 'The target architecture',                                 \
362	                                        name: 'Architecture',                                                           \
363	                                        choices: 'x64\nx86',                                                            \
364	                                        defaultValue: 'x64',                                                            \
365	                                ],                                                                                              \
366	                                [$class: 'BooleanParameterDefinition',                                                  \
367	                                        description: 'If false, only the quick test suite is ran',              \
368	                                        name: 'RunAllTests',                                                            \
369	                                        defaultValue: false,                                                            \
370	                                ],                                                                                              \
371	                                [$class: 'BooleanParameterDefinition',                                                  \
372	                                        description: 'If true, jenkins also runs benchmarks',           \
373	                                        name: 'RunBenchmark',                                                           \
374	                                        defaultValue: false,                                                            \
375	                                ],                                                                                              \
376	                                [$class: 'BooleanParameterDefinition',                                                  \
377	                                        description: 'If true, jenkins also builds documentation',              \
378	                                        name: 'BuildDocumentation',                                                     \
379	                                        defaultValue: true,                                                             \
380	                                ],                                                                                              \
381	                                [$class: 'BooleanParameterDefinition',                                                  \
382	                                        description: 'If true, jenkins also publishes results',                 \
383	                                        name: 'Publish',                                                                        \
384	                                        defaultValue: false,                                                            \
385	                                ],                                                                                              \
386	                                [$class: 'BooleanParameterDefinition',                                                  \
387	                                        description: 'If true, jenkins will not send emails',           \
388	                                        name: 'Silent',                                                                         \
389	                                        defaultValue: false,                                                            \
390	                                ],                                                                                              \
391	                        ],
392	                ]])
393	
394	        final settings = new BuildSettings(params, env.BRANCH_NAME)
395	
396	        currentBuild.description = settings.DescShort
397	        echo                       settings.DescLong
398	
399	        return settings
400	}
401	
402	def build_stage(String name, Closure block ) {
403	        StageName = name
404	        echo " -------- ${StageName} -------- "
405	        stage(name, block)
406	}
407	
408	def notify_server(int wait) {
409	        sh """curl --silent --show-error --data "wait=${wait}" -X POST https://cforall.uwaterloo.ca:8082/jenkins/notify > /dev/null || true"""
410	        return
411	}
412	
413	def make_doc() {
414	        def err = null
415	        try {
416	                sh 'make clean > /dev/null'
417	                sh 'make > /dev/null 2>&1'
418	        }
419	        catch (Exception caughtError) {
420	                err = caughtError //rethrow error later
421	                sh 'cat *.log'
422	        }
423	        finally {
424	                if (err) throw err // Must re-throw exception to propagate error
425	        }
426	}




                def changeLogSets = currentBuild.changeSets
98	 	                for (int i = 0; i < changeLogSets.size(); i++) {
99	 	                        def entries = changeLogSets[i].items
100	 	                        for (int j = 0; j < entries.length; j++) {
101	 	                                def entry = entries[j]
102	 	                                echo "${entry.commitId} by ${entry.author} on ${new Date(entry.timestamp)}: ${entry.msg}"
103	 	                                def files = new ArrayList(entry.affectedFiles)
104	 	                                for (int k = 0; k < files.size(); k++) {
105	 	                                        def file = files[k]
106	 	                                        echo "  ${file.editType.name} ${file.path}"
107	 	                                }
108	 	                        }
109	 	                }
110	 	





#!groovy

pipeline {
  agent any

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Dependecies') {
      steps {
        sh '/usr/local/bin/pod install'
      }
    }

    stage('Running Tests') {
      steps {
        parallel (
          "Unit Tests": {
            sh 'echo "Unit Tests"'
            sh 'fastlane scan'
          },
          "UI Automation": {
            sh 'echo "UI Automation"'
          }
        )
      }
    }

    stage('Documentation') {
      when {
        expression {
          env.BRANCH_NAME == 'develop'
        }
      }
      steps {
        // Generating docs
        sh 'jazzy'
        // Removing current version from web server
        sh 'rm -rf /path/to/doc/ios'
        // Copy new docs to web server
        sh 'cp -a docs/source/. /path/to/doc/ios'
      }
    }
  }

  post {
    always {
      // Processing test results
      junit 'fastlane/test_output/report.junit'
      // Cleanup
      sh 'rm -rf build'
    }
    success {
      notifyBuild()
    }
    failure {
      notifyBuild('ERROR')
    }
  }
}

// Slack notification with status and code changes from git
def notifyBuild(String buildStatus = 'SUCCESSFUL') {
  buildStatus = buildStatus

  def colorName = 'RED'
  def colorCode = '#FF0000'
  def subject = "${buildStatus}: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]'"
  def changeSet = getChangeSet()
  def message = "${subject} \n ${changeSet}"

  if (buildStatus == 'SUCCESSFUL') {
    color = 'GREEN'
    colorCode = '#00FF00'
  } else {
    color = 'RED'
    colorCode = '#FF0000'
  }

  slackSend (color: colorCode, message: message)
}

@NonCPS

// Fetching change set from Git
def getChangeSet() {
  return currentBuild.changeSets.collect { cs ->
    cs.collect { entry ->
        "* ${entry.author.fullName}: ${entry.msg}"
    }.join("\n")
  }.join("\n")
}



https://lukasmestan.com/jenkins-pipeline-example-scripts/




pipeline {
    agent { label "master"}
    stages {
        stage('1') {
            steps {
                script {
                    def tests = [:]
                    for (f in findFiles(glob: '**/html/*.html')) {
                        tests["${f}"] = {
                            node {
                                stage("${f}") {
                                    echo '${f}'
                                }
                            }
                        }
                    }
                    parallel tests
                }
            }
        }       
    }
}



Jenkins connector in Microsoft Teams sends notification about build-related activities to whichever channel the connector is configured. Below is the list of build activities that you can be notified against:
Build Start
Build Aborted
Build Failure
Build Not Built
Build Success
Build Unstable
Back To Normal
Repeated Failure


https://techcommunity.microsoft.com/t5/Microsoft-Teams-Blog/Stay-up-to-date-on-your-build-activities-with-Jenkins/ba-p/467440


https://cardano.github.io/blog/2018/03/01/microsoft-teams-jenkins-connector

 post {
        always {
            echo 'This will always run'
        }
        success {
            echo 'This will run only if successful'
            office365ConnectorSend message:"Update service in: $rancherUpdateUrl", status:"SUCCESS - Version: $versionOn", webhookUrl:"$officeWebhookUrl", color:"05b222"
        }
        failure {
            echo 'This will run only if failed'
            office365ConnectorSend message:"Build failed in Jenkins", status:"FAILED", webhookUrl:"$officeWebhookUrl", color:"d00000"
        }
        unstable {
            echo 'This will run only if the run was marked as unstable'
        }
        changed {
            echo 'This will run only if the state of the Pipeline has changed'
            echo 'For example, if the Pipeline was previously failing but is now successful'
        }
    }


Incomming hook
https://outlook.office.com/webhook/b02edea0-01f3-4530-97a4-6701b24bc4b6@30459df5-1e53-4d8b-a162-0ad2348546f1/IncomingWebhook/3f083fa6fbfc4c44af7a65715cf24032/f69f23ac-7787-48e6-95d0-b93c776c81d6
https://rharshad.com/microsoft-teams-webhook-integration/
https://cardano.github.io/blog/2018/03/01/microsoft-teams-jenkins-connector
Jenkins hook


https://engineering.21buttons.com/continuous-delivery-with-jenkins-pipelines-cc7a9f562a08

{
  "@context": "https://schema.org/extensions",
  "@type": "MessageCard",
  "themeColor": "0072C6",
  "title": "Visit the Outlook Dev Portal",
  "text": "Click **Learn More** to learn more about Actionable Messages!",
  "potentialAction": [
    {
      "@type": "ActionCard",
      "name": "Send Feedback",
      "inputs": [
        {
          "@type": "TextInput",
          "id": "feedback",
          "isMultiline": true,
          "title": "Let us know what you think about Actionable Messages"
        }
      ],
      "actions": [
        {
          "@type": "HttpPOST",
          "name": "Send Feedback",
          "isPrimary": true,
          "target": "http://..."
        }
      ]
    },
    {
      "@type": "OpenUri",
      "name": "Learn More",
      "targets": [
        { "os": "default", "uri": "https://docs.microsoft.com/outlook/actionable-messages" }
      ]
    }
  ]
}


https://docs.microsoft.com/en-us/connectors/approvals/


https://rharshad.com/microsoft-teams-webhook-integration/

{
    "@type": "MessageCard",
    "@context": "http://schema.org/extensions",
    "themeColor": "0076D7",
    "summary": "Oozie co-ordinators have been scheduled",
    "sections": [{
        "activityTitle": "Oozie co-ordinators have been scheduled",
        "activitySubtitle": "",
        "activityImage": "https://cwiki.apache.org/confluence/download/attachments/30737784/oozie_47x200.png?version=1&modificationDate=1349284899000&api=v29",
        "facts": [{
            "name": "COORDINATOR_START",
            "value": "2018-05-17T00:00Z"
        }, {
            "name": "COORDINATOR_END",
            "value": "2018-10-17T00:00"
        }],
        "markdown": true
    }],
    "potentialAction": [{
        "@type": "OpenUri",
        "name": "View Build",
        "targets": [
            { "os": "default", "uri": "https://rharshad.com/microsoft-teams-webhook-integration" }
        ]
    }]
}


post {
        success {
            script {
                def payload = """
{
    "@type": "MessageCard",
    "@context": "http://schema.org/extensions",
    "themeColor": "0076D7",
    "summary": "Oozie co-ordinators have been scheduled",
    "sections": [{
        "activityTitle": "Oozie co-ordinators have been scheduled",
        "activitySubtitle": "",
        "activityImage": "https://cwiki.apache.org/confluence/download/attachments/30737784/oozie_47x200.png?version=1&modificationDate=1349284899000&api=v29",
        "facts": [{
            "name": "COORDINATOR_START",
            "value": "${params.COORDINATOR_START}"
        }, {
            "name": "COORDINATOR_END",
            "value": "${params.COORDINATOR_END}"
        }],
        "markdown": true
    }],
    "potentialAction": [{
        "@type": "OpenUri",
        "name": "View Build",
        "targets": [
            { "os": "default", "uri": "${BUILD_URL}" }
        ]
    }]
}"""
                httpRequest httpMode: 'POST',
                        acceptType: 'APPLICATION_JSON',
                        contentType: 'APPLICATION_JSON',
                        url: "${teamsWebhookUrl}",
                        requestBody: payload
            }
        }
    }




    https://github.com/comsysto/jenkins-lab-shared-pipeline/blob/master/parallel-builds/Jenkinsfile

    // In Jenkins pipeline, everything happens on a node. For preparation work that
// doesn't require a lot of processing power, we'll use the master node:
node('master') {

    // The first stage will checkout Apache Thymeleaf and, since we do not want
    // to do that again for every integration step, stash it for later use:
    stage('Checkout ThymeLeaf') {
        git url: 'https://github.com/thymeleaf/thymeleaf.git',
            branch: '3.0-master'
        stash name: 'thymeleaf-sources',
              includes: 'pom.xml,src/*'
    }
}

// This is a custom data structure we'll use to define our parallel builds:
List<StageDef> stageDefs = [
        new StageDef("2.8.9"),
        new StageDef("2.6.3"),
        new StageDef("2.6.2"),
        new StageDef("2.0.0")]

// The branches structure is a map from branch name to branch code. This is the
// argument we'll give to the 'parallel' build step later:
def branches = [:]

// Loop through the stage definitions and define the parallel stages:
for (stageDef in stageDefs) {

    // Never inline this!
    String jacksonVersion = stageDef.jacksonVersion

    String branchName = "Build ThymeLeaf with Jackson " + jacksonVersion
    String outFileName = "thymeleaf-with-jackson-${jacksonVersion}.dependencies"

    branches[branchName] = {

        // Start the branch with a node definition. We explicitly exclude the
        // master node, so only the two slaves will do builds:
        node('!master') {
            withEnv(["PATH+MAVEN=${tool 'Maven 3'}/bin"]) {
                stage(branchName) {
                    try {
                        // First, unstash thymeleaf:
                        unstash name: 'thymeleaf-sources'

                        // Run the build, overwriting the Jackson version. We
                        // also need to skip the integrity check since we don't
                        // have access to the private signing key:
                        sh "mvn -B clean install -Djackson.version=${jacksonVersion} -Dgpg.skip=true"

                        // Store the current dependency tree to a file and stash
                        // it for the HTML report:
                        sh "mvn -B dependency:tree -Djackson.version=${jacksonVersion} | tee target/${outFileName}"
                        stash name: outFileName, includes: "target/${outFileName}"
                    }
                    catch (ignored) {
                        currentBuild.result = 'UNSTABLE'
                    }
                }
            }
        }
    }
}

parallel branches

// After completing the parallel builds, run the final step on the master node
// that collects the stashed dependency trees and produces an HTML report:
node('master') {
    stage('Publish Report') {
        sh "mkdir -p target"
        writeFile file: "target/integration-result.html",
                  text: buildHtmlReport(stageDefs)
        publishHTML([
                allowMissing         : false,
                alwaysLinkToLastBuild: true,
                keepAll              : true,
                reportDir            : 'target',
                reportFiles          : 'integration-result.html',
                reportName           : 'Integration result'])
    }
}

private String buildHtmlReport(List<StageDef> stageDefs) {
    def s = "<p><b>Build ${env.BUILD_NUMBER}</b>: </p><p><table border='0' width='50%'>"

    for (stageDef in stageDefs) {
        String jacksonVersion = stageDef.jacksonVersion
        String outFileName = "thymeleaf-with-jackson-${jacksonVersion}.dependencies"

        try {
            unstash name: outFileName
            success = true
        }
        catch (ignored) {
            success = false
        }
        s += "<tr>" +
             "<td width='30%'>Built with Jackson ${stageDef.jacksonVersion}</td>" +
             "<td width='5%'>&nbsp;</td>" +
             "<td width='20%'>" +

             // Per default, Jenkins filters out all CSS styling, so we use
             // some deprecated HTML 3.x to color the result:
             "${success ? "<font color='green'>SUCCESS</font>" : "<font color='red'>FAILURE</font>"}" +
             "</td>" +
             "<td width='5%'>&nbsp;</td>" +
             "<td width='45%'>${success ? "<a href='${outFileName}'>Dependency Tree</a>" : ""}</td>" +
             "</tr>"
    }
    s += "</table></p>"
    return s
}

// This structure is so simple that we could as well have used only a simple
// string. This more complicated variant was chosen to serve as a template for
// real-world stages definitions that may not be as simple:
class StageDef implements Serializable {

    String jacksonVersion

    StageDef(final String jacksonVersion) {
        this.jacksonVersion = jacksonVersion
    }
}


https://devops.stackexchange.com/questions/986/how-to-build-a-complex-parallel-jenkins-pipeline
https://engineering.21buttons.com/continuous-delivery-with-jenkins-pipelines-cc7a9f562a08

https://stackoverflow.com/questions/40224272/using-a-jenkins-pipeline-to-checkout-multiple-git-repos-into-same-job
https://bjurr.com/managing-1000-repos-in-jenkins-with-a-breeze/
https://codebabel.com/branching-merging-git/

https://www.voxxed.com/2017/01/pipeline-as-code-with-jenkins-2/

step([$class: 'CucumberReportPublisher', jsonReportDirectory: "./Build/temp/", jenkinsBasePath: '', fileIncludePattern: 'reports.json'])
https://github.com/jenkinsci/cucumber-reports-plugin


https://developer.oracle.com/containers/automatic-code-deployment







##########  AMAZING ############

https://www.juvo.be/blog/pipeline-builds-devops-environment

pipeline {
  agent any
  parameters {
    booleanParam(name: 'DEPLOYS', defaultValue: false, description: 'Use this build for deployment.')
 }
  triggers {
    pollSCM('H/10 * * * * ')
  }
  environment {
    JAVA_HOME="${tool 'Java8'}"
    PATH="${env.JAVA_HOME}/bin:${env.PATH}"
  }
  tools {
    maven "Maven3"
    jdk "Java8"
  }
  stages {
  }
}
Script your stages
Our build and release process consists out of multiple stages. Each stage has a unique name and steps that must be performed. A step can be for example:

Checkout your code
Run a shell command
Send a Hipchat message
Wait for user input
...
The prepare stage checks out our SCM code

stage('Prepare') {
      steps {
        checkout scm
      }
    }
, while the build stage performs a maven build.

  stage('Build') {
      steps {
        sh "mvn -T 4 -P theme clean install"
      }
    }


Only in case of a successful deployment on the test environment a deployment on the acceptance environment can be done. The same is the case for production: only a successful deployment on acceptance can lead to a deployment on production.

stage('Approve deployment on UAT') {
      when {
        environment name: 'DEPLOY_TST', value: "true"
      }
      steps {
        timeout(time: 7, unit: 'DAYS') {
          script {
           env.DEPLOY_UAT = input message: 'Approve deployment', parameters: [
              [$class: 'BooleanParameterDefinition', defaultValue: false, description: '', name: 'Approve deployment on UAT']
            ]
          }
        }
      }
    }

  https://nvie.com/posts/a-successful-git-branching-model/

      stage('Approve deployment on PRD') {
      when {
        branch 'master'
        environment name: 'DEPLOY_TST', value: "true"
        environment name: 'DEPLOY_UAT', value: "true"
      }
      steps {
        timeout(time: 14, unit: 'DAYS') {
          script {
           env.DEPLOY_PRD = input message: 'Approve deployment', parameters: [
              [$class: 'BooleanParameterDefinition', defaultValue: false, description: '', name: 'Approve deployment on PRD']
            ]
          }
        }
      }
    }





In the end, if everything went well and you manually triggered the build, you want to deploy your code on the test environment. In this case the user was asked if he wanted to use the build for a deployment. If he said yes, the steps of the approval stage are executed and the user is asked to approve the deployment to the test environment. He has one hour to react on the question: if he hasn’t approved the deployment in time, the build process is ended.

  stage('Approve deployment on TST') {
      when {
        expression { return params.DEPLOYS }
      }
      steps {
        timeout(time: 1, unit: 'HOURS') {
          script {
            env.DEPLOY_TST = input message: 'Approve deployment', parameters: [
              [$class: 'BooleanParameterDefinition', defaultValue: false, description: '', name: 'Approve deployment on TST']
            ]
          }
        }
      }
    }
When the deployment was approved, the build steps can be executed.

stage('Deploy on TST') {
      when {
        environment name: 'DEPLOY_TST', value: "true"
      }
      steps {
        …
      }
    }


https://www.baeldung.com/jenkins-pipelines
https://github.com/eugenp/tutorials/blob/master/spring-jenkins-pipeline/scripted-pipeline-unix-nonunix