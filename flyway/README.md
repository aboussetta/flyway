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

https://engineering.medallia.com/blog/posts/parallelizing-jenkins-pipelines/

https://github.com/jenkinsci/pipeline-examples/blob/master/pipeline-examples/timestamper-wrapper/timestamperWrapper.groovy


// This shows a simple build wrapper example, using the Timestamper plugin.
node {
    // Adds timestamps to the output logged by steps inside the wrapper.
    timestamps {
        // Just some echoes to show the timestamps.
        stage "First echo"
        echo "Hey, look, I'm echoing with a timestamp!"

        // A sleep to make sure we actually get a real difference!
        stage "Sleeping"
        sleep 30

        // And a final echo to show the time when we wrap up.
        stage "Second echo"
        echo "Wonder what time it is now?"
    }
}



GIT_REPOS=`curl -s curl https://${GITHUB_BASE_URL}/api/v3/orgs/${ORG_NAME}/repos?access_token=${ACCESS_TOKEN} | grep ssh_url | awk -F': ' '{print $2}' | sed -e 's/",//g' | sed -e 's/"//g'`
for REPO in $GIT_REPOS; do
  git clone $REPO
done



user="https://github.com/user/"
declare -a arr=("repo1", "repo2")
for i in "${arr[@]}"
do
   echo $user"$i"
   git clone $user"$i"
done 


NUM_REPOS=1000
DW_FOLDER="Github_${NUM_REPOS}_repos"
cd ${DW_FOLDER}
for REPO in $(curl https://api.github.com/users/${GITHUB_USER}/repos?per_page=${NUM_REPOS} | awk '/ssh_url/{print $2}' | sed 's/^"//g' | sed 's/",$//g') ; do git clone ${REPO} ; done





#!groovy
pipeline {
agent {
  docker {
    image 'jenkinsslave:latest'
    registryUrl 'http://8598567586.dkr.ecr.us-west-2.amazonaws.com'
    registryCredentialsId 'ecr:us-east-1:3435443545-5546566-567765-3225'
    args '-v /home/centos/.ivy2:/home/jenkins/.ivy2:rw -v jenkins_opt:/usr/local/bin/opt -v jenkins_apijenkins:/home/jenkins/config -v jenkins_logs:/var/logs -v jenkins_awsconfig:/home/jenkins/.aws --privileged=true -u jenkins:jenkins'
  }
}
environment {
    APP_NAME = 'billing-rest'
    BUILD_NUMBER = "${env.BUILD_NUMBER}"
    IMAGE_VERSION="v_${BUILD_NUMBER}"
    GIT_URL="git@github.yourdomain.com:mpatel/${APP_NAME}.git"
    GIT_CRED_ID='izleka2IGSTDK+MiYOG3b3lZU9nYxhiJOrxhlaJ1gAA='
    REPOURL = 'cL5nSDa+49M.dkr.ecr.us-east-1.amazonaws.com'
    SBT_OPTS='-Xmx1024m -Xms512m'
    JAVA_OPTS='-Xmx1024m -Xms512m'
    WS_PRODUCT_TOKEN='FJbep9fKLeJa/Cwh7IJbL0lPfdYg7q4zxvALAxWPLnc='
    WS_PROJECT_TOKEN='zwzxtyeBntxX4ixHD1iE2dOr4DVFHPp7D0Czn84DEF4='
    HIPCHAT_TOKEN = 'SpVaURsSTcWaHKulZ6L4L+sjKxhGXCkjSbcqzL42ziU='
    HIPCHAT_ROOM = 'NotificationRoomName'
}

options {
    buildDiscarder(logRotator(artifactDaysToKeepStr: '', artifactNumToKeepStr: '', daysToKeepStr: '10', numToKeepStr: '20'))
    timestamps()
    retry(3)
    timeout time:10, unit:'MINUTES'
}
parameters {
    string(defaultValue: "develop", description: 'Branch Specifier', name: 'SPECIFIER')
    booleanParam(defaultValue: false, description: 'Deploy to QA Environment ?', name: 'DEPLOY_QA')
    booleanParam(defaultValue: false, description: 'Deploy to UAT Environment ?', name: 'DEPLOY_UAT')
    booleanParam(defaultValue: false, description: 'Deploy to PROD Environment ?', name: 'DEPLOY_PROD')
}
stages {
    stage("Initialize") {
        steps {
            script {
                notifyBuild('STARTED')
                echo "${BUILD_NUMBER} - ${env.BUILD_ID} on ${env.JENKINS_URL}"
                echo "Branch Specifier :: ${params.SPECIFIER}"
                echo "Deploy to QA? :: ${params.DEPLOY_QA}"
                echo "Deploy to UAT? :: ${params.DEPLOY_UAT}"
                echo "Deploy to PROD? :: ${params.DEPLOY_PROD}"
                sh 'rm -rf target/universal/*.zip'
            }
        }
    }
stage('Checkout') {
    steps {
        git branch: "${params.SPECIFIER}", url: "${GIT_URL}"
    }
}
stage('Build') {
            steps {
                echo 'Run coverage and CLEAN UP Before please'
                sh '/usr/local/bin/opt/bin/sbtGitActivator; /usr/local/bin/opt/play-2.5.10/bin/activator -Dsbt.global.base=.sbt -Dsbt.ivy.home=/home/jenkins/.ivy2 -Divy.home=/home/jenkins/.ivy2 compile coverage test coverageReport coverageOff dist'
            }
        }
stage('Publish Reports') {
    parallel {
        stage('Publish FindBugs Report') {
            steps {
                step([$class: 'FindBugsPublisher', canComputeNew: false, defaultEncoding: '', excludePattern: '', healthy: '', includePattern: '', pattern: 'target/scala-2.11/findbugs/report.xml', unHealthy: ''])
            }
        }
        stage('Publish Junit Report') {
            steps {
                junit allowEmptyResults: true, testResults: 'target/test-reports/*.xml'
            }
        }
        stage('Publish Junit HTML Report') {
            steps {
                publishHTML target: [
                        allowMissing: true,
                        alwaysLinkToLastBuild: false,
                        keepAll: true,
                        reportDir: 'target/reports/html',
                        reportFiles: 'index.html',
                        reportName: 'Test Suite HTML Report'
                ]
            }
        }
        stage('Publish Coverage HTML Report') {
            steps {
                publishHTML target: [
                        allowMissing: true,
                        alwaysLinkToLastBuild: false,
                        keepAll: true,
                        reportDir: 'target/scala-2.11/scoverage-report',
                        reportFiles: 'index.html',
                        reportName: 'Code Coverage'
                ]
            }
        }
        stage('Execute Whitesource Analysis') {
            steps {
                whitesource jobApiToken: '', jobCheckPolicies: 'global', jobForceUpdate: 'global', libExcludes: '', libIncludes: '', product: "${env.WS_PRODUCT_TOKEN}", productVersion: '', projectToken: "${env.WS_PROJECT_TOKEN}", requesterEmail: ''
            }
        }
        stage('SonarQube analysis') {
            steps {
                sh "/usr/bin/sonar-scanner"
            }
        }
        stage('ArchiveArtifact') {
            steps {
                archiveArtifacts '**/target/universal/*.zip'
            }
        }
    }
}

 stage('Docker Tag & Push') {
     steps {
         script {
             branchName = getCurrentBranch()
             shortCommitHash = getShortCommitHash()
             IMAGE_VERSION = "${BUILD_NUMBER}-" + branchName + "-" + shortCommitHash
             sh 'eval $(aws ecr get-login --no-include-email --region us-west-2)'
             sh "docker-compose build"
             sh "docker tag ${REPOURL}/${APP_NAME}:latest ${REPOURL}/${APP_NAME}:${IMAGE_VERSION}"
             sh "docker push ${REPOURL}/${APP_NAME}:${IMAGE_VERSION}"
             sh "docker push ${REPOURL}/${APP_NAME}:latest"

             sh "docker rmi ${REPOURL}/${APP_NAME}:${IMAGE_VERSION} ${REPOURL}/${APP_NAME}:latest"
         }
     }
 }
stage('Deploy') {
    parallel {
        stage('Deploy to CI') {
            steps {
                echo "Deploying to CI Environment."
            }
        }

        stage('Deploy to QA') {
            when {
                expression {
                    params.DEPLOY_QA == true
                }
            }
            steps {
                echo "Deploy to QA..."
            }
        }
        stage('Deploy to UAT') {
            when {
                expression {
                    params.DEPLOY_UAT == true
                }
            }
            steps {
                echo "Deploy to UAT..."
            }
        }
        stage('Deploy to Production') {
            when {
                expression {
                    params.DEPLOY_PROD == true
                }
            }
            steps {
                echo "Deploy to PROD..."
            }
        }
    }
}
}

    post {
        /*
         * These steps will run at the end of the pipeline based on the condition.
         * Post conditions run in order regardless of their place in the pipeline
         * 1. always - always run
         * 2. changed - run if something changed from the last run
         * 3. aborted, success, unstable or failure - depending on the status
         */
        always {
            echo "I AM ALWAYS first"
            notifyBuild("${currentBuild.currentResult}")
        }
        aborted {
            echo "BUILD ABORTED"
        }
        success {
            echo "BUILD SUCCESS"
            echo "Keep Current Build If branch is master"
//            keepThisBuild()
        }
        unstable {
            echo "BUILD UNSTABLE"
        }
        failure {
            echo "BUILD FAILURE"
        }
    }
}
def keepThisBuild() {
    currentBuild.setKeepLog(true)
    currentBuild.setDescription("Test Description")
}

def getShortCommitHash() {
    return sh(returnStdout: true, script: "git log -n 1 --pretty=format:'%h'").trim()
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



Conditions
always
Run the steps in the post section regardless of the completion status of the Pipeline’s or stage’s run.

changed
Only run the steps in post if the current Pipeline’s or stage’s run has a different completion status from its previous run.

fixed
Only run the steps in post if the current Pipeline’s or stage’s run is successful and the previous run failed or was unstable.

regression
Only run the steps in post if the current Pipeline’s or stage’s run’s status is failure, unstable, or aborted and the previous run was successful.

aborted
Only run the steps in post if the current Pipeline’s or stage’s run has an "aborted" status, usually due to the Pipeline being manually aborted. This is typically denoted by gray in the web UI.

failure
Only run the steps in post if the current Pipeline’s or stage’s run has a "failed" status, typically denoted by red in the web UI.

success
Only run the steps in post if the current Pipeline’s or stage’s run has a "success" status, typically denoted by blue or green in the web UI.

unstable
Only run the steps in post if the current Pipeline’s or stage’s run has an "unstable" status, usually caused by test failures, code violations, etc. This is typically denoted by yellow in the web UI.

unsuccessful
Only run the steps in post if the current Pipeline’s or stage’s run has not a "success" status. This is typically denoted in the web UI depending on the status previously mentioned

cleanup
Run the steps in this post condition after every other post condition has been evaluated, regardless of the Pipeline or stage’s status.

Example



Available Options
buildDiscarder
Persist artifacts and console output for the specific number of recent Pipeline runs. For example: options { buildDiscarder(logRotator(numToKeepStr: '1')) }

checkoutToSubdirectory
Perform the automatic source control checkout in a subdirectory of the workspace. For example: options { checkoutToSubdirectory('foo') }

disableConcurrentBuilds
Disallow concurrent executions of the Pipeline. Can be useful for preventing simultaneous accesses to shared resources, etc. For example: options { disableConcurrentBuilds() }

newContainerPerStage
Used with docker or dockerfile top-level agent. When specified, each stage will run in a new container instance on the same node, rather than all stages running in the same container instance.

overrideIndexTriggers
Allows overriding default treatment of branch indexing triggers. If branch indexing triggers are disabled at the multibranch or organization label, options { overrideIndexTriggers(true) } will enable them for this job only. Otherwise, options { overrideIndexTriggers(false) } will disable branch indexing triggers for this job only.

preserveStashes
Preserve stashes from completed builds, for use with stage restarting. For example: options { preserveStashes() } to preserve the stashes from the most recent completed build, or options { preserveStashes(buildCount: 5) } to preserve the stashes from the five most recent completed builds.

quietPeriod
Set the quiet period, in seconds, for the Pipeline, overriding the global default. For example: options { quietPeriod(30) }

retry
On failure, retry the entire Pipeline the specified number of times. For example: options { retry(3) }

skipDefaultCheckout
Skip checking out code from source control by default in the agent directive. For example: options { skipDefaultCheckout() }

skipStagesAfterUnstable
Skip stages once the build status has gone to UNSTABLE. For example: options { skipStagesAfterUnstable() }

timeout
Set a timeout period for the Pipeline run, after which Jenkins should abort the Pipeline. For example: options { timeout(time: 1, unit: 'HOURS') }

timestamps
Prepend all console output generated by the Pipeline run with the time at which the line was emitted. For example: options { timestamps() }

parallelsAlwaysFailFast
Set failfast true for all subsequent parallel stages in the pipeline. For example: options { parallelsAlwaysFailFast() }



Available Parameters
string
A parameter of a string type, for example: parameters { string(name: 'DEPLOY_ENV', defaultValue: 'staging', description: '') }

text
A text parameter, which can contain multiple lines, for example: parameters { text(name: 'DEPLOY_TEXT', defaultValue: 'One\nTwo\nThree\n', description: '') }

booleanParam
A boolean parameter, for example: parameters { booleanParam(name: 'DEBUG_BUILD', defaultValue: true, description: '') }

choice
A choice parameter, for example: parameters { choice(name: 'CHOICES', choices: ['one', 'two', 'three'], description: '') }

file
A file parameter, which specifies a file to be submitted by the user when scheduling a build, for example: parameters { file(name: 'FILE', description: 'Some file to upload') }

password
A password parameter, for example: parameters { password(name: 'PASSWORD', defaultValue: 'SECRET', description: 'A secret password') }




tools
A section defining tools to auto-install and put on the PATH. This is ignored if agent none is specified.

Required

No

Parameters

None

Allowed

Inside the pipeline block or a stage block.

Supported Tools
maven
jdk
gradle



input
The input directive on a stage allows you to prompt for input, using the input step. The stage will pause after any options have been applied, and before entering the stage`s `agent or evaluating its when condition. If the input is approved, the stage will then continue. Any parameters provided as part of the input submission will be available in the environment for the rest of the stage.

Configuration options
message
Required. This will be presented to the user when they go to submit the input.

id
An optional identifier for this input. Defaults to the stage name.

ok
Optional text for the "ok" button on the input form.

submitter
An optional comma-separated list of users or external group names who are allowed to submit this input. Defaults to allowing any user.

submitterParameter
An optional name of an environment variable to set with the submitter name, if present.

parameters
An optional list of parameters to prompt the submitter to provide. See parameters for more information.





Built-in Conditions
branch
Execute the stage when the branch being built matches the branch pattern given, for example: when { branch 'master' }. Note that this only works on a multibranch Pipeline.

buildingTag
Execute the stage when the build is building a tag. Example: when { buildingTag() }

changelog
Execute the stage if the build’s SCM changelog contains a given regular expression pattern, for example: when { changelog '.*^\\[DEPENDENCY\\] .+$' }

changeset
Execute the stage if the build’s SCM changeset contains one or more files matching the given string or glob. Example: when { changeset "**/*.js" }

By default the path matching will be case insensitive, this can be turned off with the caseSensitive parameter, for example: when { changeset glob: "ReadMe.*", caseSensitive: true }

changeRequest
Executes the stage if the current build is for a "change request" (a.k.a. Pull Request on GitHub and Bitbucket, Merge Request on GitLab or Change in Gerrit etc.). When no parameters are passed the stage runs on every change request, for example: when { changeRequest() }.

By adding a filter attribute with parameter to the change request, the stage can be made to run only on matching change requests. Possible attributes are id, target, branch, fork, url, title, author, authorDisplayName, and authorEmail. Each of these corresponds to a CHANGE_* environment variable, for example: when { changeRequest target: 'master' }.

The optional parameter comparator may be added after an attribute to specify how any patterns are evaluated for a match: EQUALS for a simple string comparison (the default), GLOB for an ANT style path glob (same as for example changeset), or REGEXP for regular expression matching. Example: when { changeRequest authorEmail: "[\\w_-.]+@example.com", comparator: 'REGEXP' }

environment
Execute the stage when the specified environment variable is set to the given value, for example: when { environment name: 'DEPLOY_TO', value: 'production' }

equals
Execute the stage when the expected value is equal to the actual value, for example: when { equals expected: 2, actual: currentBuild.number }

expression
Execute the stage when the specified Groovy expression evaluates to true, for example: when { expression { return params.DEBUG_BUILD } } Note that when returning strings from your expressions they must be converted to booleans or return null to evaluate to false. Simply returning "0" or "false" will still evaluate to "true".

tag
Execute the stage if the TAG_NAME variable matches the given pattern. Example: when { tag "release-*" }. If an empty pattern is provided the stage will execute if the TAG_NAME variable exists (same as buildingTag()).

The optional parameter comparator may be added after an attribute to specify how any patterns are evaluated for a match: EQUALS for a simple string comparison, GLOB (the default) for an ANT style path glob (same as for example changeset), or REGEXP for regular expression matching. For example: when { tag pattern: "release-\\d+", comparator: "REGEXP"}

not
Execute the stage when the nested condition is false. Must contain one condition. For example: when { not { branch 'master' } }

allOf
Execute the stage when all of the nested conditions are true. Must contain at least one condition. For example: when { allOf { branch 'master'; environment name: 'DEPLOY_TO', value: 'production' } }

anyOf
Execute the stage when at least one of the nested conditions is true. Must contain at least one condition. For example: when { anyOf { branch 'master'; branch 'staging' } }

triggeredBy
Execute the stage when the current build has been triggered by the param given. For example:

when { triggeredBy 'SCMTrigger' }

when { triggeredBy 'TimerTrigger' }

when { triggeredBy 'UpstreamCause' }

when { triggeredBy cause: "UserIdCause", detail: "vlinde" }



#!/usr/bin/env groovy
userInput = ""
stage('Choose environment') {
  userInput = input(id: 'userInput',    
                    message: 'Choose an environment',    
                    parameters: [
                      [$class: 'ChoiceParameterDefinition', choices: "Dev\nQA\nProd", name: 'Env']
                           ]  
  )
}
stage('Deploy code'){
  node('deploy'){
    if (userInput.Env == "Dev") {
      // deploy dev stuff
    } else if (userInput.Env == "QA"){
      // deploy qa stuff
    } else {
      // deploy prod stuff
  }
}


stage('deploy'){
  node('aws'){
    sh """          
    ### Create stack with new code          
    aws cloudformation create-stack \            
      --region us-west-2 \            
      --capabilities CAPABILITY_IAM \            
      --stack-name app-${GIT_BRANCH}-${BUILD_NUMBER} \            
      --template-body file://cf/template.yaml
    """
  }
}


passThis = "input of some kind"
stage('run script'){
  node('jenkins-worker'){
    sh '''#!/bin/bash
    scripts/do-the-thing.sh '''+passThis+'''
    #more code
    '''
  }
}


try {
  node('deployment') {
    // deploy code
  } catch (err) {
    // do stuff! maybe fire off a Slack notification?
    notify("#dev", "@here ${JOB} failed during build")
    // and now fail the pipeline by re-throwing the error
    throw err
  }
}


def notify(channel,text) {  
  slackSend (channel: "${channel}", message: "${text}", teamDomain: "$YOURTEAMDOMAIN", token: "$YOURSLACKTOKEN")  
}





node('NODE NAME') 
{ 
    withEnv([REQUIRED ENV VARIBALES]) 
    {   withCredentials([[$class: 'UsernamePasswordMultiBinding', credentialsId: 'CREDENTIALS ID', passwordVariable: 'PW', usernameVariable: 'USER']]) 
        {   try 
                {   stage 'Build' 
                        checkout changelog: false, poll: false, scm: [$class: 'GitSCM', branches: [[name: gitbranch]], doGenerateSubmoduleConfigurations: false, 
                                  extensions: [], submoduleCfg: [], userRemoteConfigs: [[credentialsId: 'CREDENTIALS ID', 
                                  url: 'GIT URL']]]

                                ****
                                MAVEN BUILD
                                ****

                    stage 'Docker Image build & Push'
                                *****
                                DOCKER BUILD AND PUSH TO REPO
                                *****
                }
              catch (err) {
                notify("Failed ${err}")
                currentBuild.result = 'FAILURE'
                }

                stage 'Deploy to ENV'

                *****
                DEPLOYMENT TO REQUIRED ENV
                *****

                notify('Success -Deployed to Environment')

                catch (err) {
                 notify("Failed ${err}")
                currentBuild.result = 'FAILURE'
                } 
        }   
    }
}

def notify(status)
{
****
NOTIFICATION FUCNTION
****
}

https://github.com/vamsigoli/sakila-h2-files

java -cp h2-1.4.197.jar org.h2.tools.RunScript -url jdbc:h2:~/testsakila;MODE=Oracle -user flyway -password test123 -script c:\Users\vamsi\Downloads\oracle-sakila-db\oracle-sakila-schema.sql

parmesan:drivers abderrahim.boussetta$ java -cp drivers/h2-1.4.197.jar org.h2.tools.RunScript -url jdbc:h2:file:/Users/abderrahim.boussetta/.jenkins/workspace/flyway_pipeline_oracle -script V15__add_ayah_table.sql;MODE=ORACLE


parmesan:flyway-5.2.4 abderrahim.boussetta$ java -cp drivers/ojdbc8.jar org.h2.tools.RunScript -url jdbc:oracle:thin:@//hhdora-scan.dev.hh.perform.local:1521/DV_FLYWAY;MODE=Oracle -user flyway -password flyway_123 -script /Users/abderrahim.boussetta/.jenkins/workspace/flyway_pipeline_oracle/V15__add_ayah_table.sql



flyway migrate -target=1.2. 


But, if you choose to prefix your migrations using timestamps rather than integers, then the likelihood of a collision virtually disappears, even across branches.  For example, using a pattern such as yyyyMMddHHmmssSSS the migrations above now look like…

20130704144750766__add_customers_table.sql
20130706132142244__add_email_address_column_to_customers_table.sql
20130706151409978__add_orders_table_with_reference_to_customer_table.sql



task prefixNewMigrations {

  fileTree(dir: 'dev/src/db/listhub').exclude({ isFilePrefixed(it.file) }).each { file ->
        doLast {

        	def timestamp = new Date().format('yyyyMMddHHmmssSSS', TimeZone.getTimeZone('GMT'))

        	println "Renaming $file.name to ${timestamp}__$file.name"
        	
        	file.renameTo("$file.parentFile.absolutePath$file.separator${timestamp}__$file.name")
        	
        	// Sleep for a moment to avoid prefix conflicts when renaming multiple files
        	sleep(1*1000)
        }
    }
}

def isFilePrefixed(file) {
	return (file.name ==~ '^\\d+__.*\\.sql\$')
}





Also:   java.lang.NoSuchMethodError: No such DSL method 'steps' found among steps [ansiblePlaybook, ansibleVault, archive, bat, build, catchError, checkout, cucumberSlackSend, deleteDir, dir, dockerFingerprintFrom, dockerFingerprintRun, echo, emailext, emailextrecipients, envVarsForTool, error, fileExists, getContext, git, githubNotify, input, isUnix, jiraAddComment, jiraAddWatcher, jiraAssignIssue, jiraAssignableUserSearch, jiraComment, jiraDeleteAttachment, jiraDeleteIssueLink, jiraDeleteIssueRemoteLink, jiraDeleteIssueRemoteLinks, jiraDownloadAttachment, jiraEditComment, jiraEditComponent, jiraEditIssue, jiraEditVersion, jiraGetAttachmentInfo, jiraGetComment, jiraGetComments, jiraGetComponent, jiraGetComponentIssueCount, jiraGetFields, jiraGetIssue, jiraGetIssueLink, jiraGetIssueLinkTypes, jiraGetIssueRemoteLink, jiraGetIssueRemoteLinks, jiraGetIssueTransitions, jiraGetIssueWatches, jiraGetProject, jiraGetProjectComponents, jiraGetProjectStatuses, jiraGetProjectVersions, jiraGetProjects, jiraGetServerInfo, jiraGetVersion, jiraIssueSelector, jiraJqlSearch, jiraLinkIssues, jiraNewComponent, jiraNewIssue, jiraNewIssueRemoteLink, jiraNewIssues, jiraNewVersion, jiraNotifyIssue, jiraSearch, jiraTransitionIssue, jiraUploadAttachment, jiraUserSearch, junit, library, libraryResource, load, lock, mail, milestone, node, office365ConnectorSend, parallel, powershell, properties, publishHTML, pwd, readFile, readTrusted, resolveScm, retry, script, setGitHubPullRequestStatus, sh, slackSend, sleep, stage, stash, step, svn, timeout, timestamps, tm, tool, unarchive, unstash, validateDeclarativePipeline, waitUntil, withContext, withCredentials, withDockerContainer, withDockerRegistry, withDockerServer, withEnv, wrap, writeFile, ws] or symbols [Number, Open, all, allOf, allowRunOnStatus, always, ant, antFromApache, antOutcome, antTarget, any, anyOf, apiToken, architecture, archiveArtifacts, artifactManager, asIsGITScm, authorizationMatrix, batchFile, bitbucket, booleanParam, branch, branchCreated, branches, brokenBuildSuspects, brokenTestsSuspects, buildButton, buildDiscarder, buildParameter, buildingTag, caseInsensitive, caseSensitive, certificate, changeRequest, changelog, changeset, checkoutToSubdirectory, choice, choiceParam, cleanWs, clock, close, cloud, command, commentPattern, commit, commitChanged, commitMessagePattern, configFile, configFileProvider, copyArtifactPermission, copyArtifacts, created, credentials, cron, crumb, cucumber, culprits, defaultView, deleted, demand, description, developers, disableConcurrentBuilds, disableResume, docker, dockerCert, dockerfile, downloadFeatureFiles, downloadSettings, downstream, dumb, durabilityHint, envVars, environment, equals, expression, file, fileParam, filePath, fingerprint, flyway, flywayrunner, frameOptions, freeStyle, freeStyleJob, fromScm, fromSource, git, gitHub, gitHubEvents, gitHubPRStatus, gitHubPlugin, github, githubBranches, githubPRAddLabels, githubPRClosePublisher, githubPRComment, githubPRMessage, githubPRRemoveLabels, githubPRStatusPublisher, githubPlugin, githubPullRequests, githubPush, globalConfigFiles, gradle, hashChanged, headRegexFilter, headWildcardFilter, hyperlink, hyperlinkToModels, inheriting, inheritingGlobal, installSource, isRestartedRun, jdk, jdkInstaller, jgit, jgitapache, jiraArrayEntry, jiraSelectableArrayField, jiraSelectableField, jiraStringArrayField, jiraStringField, jiraTestResultReporter, jnlp, jobName, label, labels, labelsAdded, labelsExist, labelsNotExist, labelsPatternExists, labelsRemoved, lastCompleted, lastDuration, lastFailure, lastGrantedAuthorities, lastStable, lastSuccess, lastSuccessful, lastWithArtifacts, latestSavedBuild, legacy, legacySCM, list, livingDocs, local, location, logRotator, loggedInUsersCanDoAnything, masterBuild, maven, maven3Mojos, mavenErrors, mavenMojos, mavenWarnings, message, modernSCM, myView, newContainerPerStage, noGITScm, node, nodeProperties, nonInheriting, nonMergeable, none, not, office365ConnectorSend, office365ConnectorWebhooks, overrideIndexTriggers, paneStatus, parallelsAlwaysFailFast, parameters, password, pattern, permalink, permanent, pipeline-model, pipelineTriggers, plainText, plugin, pollSCM, preserveStashes, projectNamingStrategy, proxy, publishTestResults, pullRequest, pullRequests, queueItemAuthenticator, quietPeriod, rateLimitBuilds, recipients, requestor, restriction, restrictions, run, runParam, s3CopyArtifact, s3Upload, schedule, scmRetryCount, scriptApprovalLink, search, security, shell, skipDefaultCheckout, skipStagesAfterUnstable, slackNotifier, slave, sourceRegexFilter, sourceWildcardFilter, specific, sshUserPrivateKey, stackTrace, standard, status, statusOnPublisherError, string, stringParam, swapSpace, tag, tags, text, textParam, tmpSpace, toolLocation, triggeredBy, unsecured, upstream, upstreamDevelopers, userSeed, usernameColonPassword, usernamePassword, viewsTabBar, weather, withAnt, workspace, zfs, zip] or globals [currentBuild, docker, env, params, pipeline, scm]



def releaseTag, activeSvc, canarySvc

pipeline {
  agent any

  stages {
    stage('Select Version') {
      steps {
        script {
          openshift.withCluster() {
            openshift.withProject('dev') {
              def tags = openshift.selector("istag").objects().collect { it.metadata.name }.findAll { it.startsWith 'mapit-spring:' }.collect { it.replaceAll(/mapit-spring:(.*)/, "\$1") }.sort()
  
              timeout(10) {
                releaseTag = input(
                  ok: "Deploy",
                  message: "Enter release version to promote to PROD",
                  parameters: [
                    choice(choices: tags.join('\n'), description: '', name: 'Release Version')
                  ]
                )
              }
            }
          }
        }
      }
    }
    stage('Deploy Canary 10%') {
      steps {
        script {
          openshift.withCluster() {
            openshift.withProject('prod') {
              openshift.tag("dev/mapit-spring:${releaseTag}", "prod/mapit-spring:${releaseTag}")

              activeSvc = openshift.selector("route", "mapit-spring").object().spec.to.name
              def suffix = (activeSvc ==~ /mapit-spring-(\d+)/) ? (activeSvc.replaceAll(/mapit-spring-(\d+)/, '$1') as int) + 1 : "1"
              canarySvc = "mapit-spring-${suffix}"

              def dc = openshift.newApp("mapit-spring:${releaseTag}", "--name=${canarySvc}").narrow('dc')
              openshift.set("probe dc/${canarySvc} --readiness --get-url=http://:8080/ --initial-delay-seconds=30 --failure-threshold=10 --period-seconds=10")
              openshift.set("probe dc/${canarySvc} --liveness  --get-url=http://:8080/ --initial-delay-seconds=180 --failure-threshold=10 --period-seconds=10")

              dc.rollout().status()

              openshift.set("route-backends", "mapit-spring", "${activeSvc}=90%", "${canarySvc}=10%")
            }
          }
        }
      }
    }
    stage('Grow Canary 50%') {
      steps {
        timeout(time:15, unit:'MINUTES') {
            input message: "Send 50% of live traffic to new release?", ok: "Approve"
        }
        script {
          openshift.withCluster() {
            openshift.withProject('prod') {
              openshift.set("route-backends", "mapit-spring", "${activeSvc}=50%", "${canarySvc}=50%")
            }
          }
        }
      }
    }
    stage('Rollout 100%') {
      steps {
        timeout(time:15, unit:'MINUTES') {
            input message: "Send 100% of live traffic to the new release?", ok: "Approve"
        }
        script {
          openshift.withCluster() {
            openshift.withProject('prod') {
              openshift.set("route-backends", "mapit-spring", "${canarySvc}=100%")
              openshift.selector(["dc/${activeSvc}", "svc/${activeSvc}"]).delete()
            }
          }
        }
      }
    }
  }
  post { 
    aborted {
      script {
        openshift.withCluster() {
          openshift.withProject('prod') {
            echo "Rolling back to current release ${activeSvc} and deleting the canary"
            openshift.set("route-backends", "mapit-spring", "${activeSvc}=100%")
            openshift.selector(["dc/${canarySvc}", "svc/${canarySvc}"]).delete()
          }
        }
      }
    }
    failure { 
      script {
        openshift.withCluster() {
          openshift.withProject('prod') {
            echo "Rolling back to current release ${activeSvc} and deleting the canary"
            openshift.set("route-backends", "mapit-spring", "${activeSvc}=100%")
            openshift.selector(["dc/${canarySvc}", "svc/${canarySvc}"]).delete()
          }
        }
      }
    }
  }
}


#!groovy

node("docker-light") {

  stage "Verify author"
  def power_users = ["ktf", "dberzano"]
  def deployable_branches = ["master"]
  echo "Changeset from " + env.CHANGE_AUTHOR
  if (power_users.contains(env.CHANGE_AUTHOR)) {
    echo "PR comes from power user. Testing"
  } else if(deployable_branches.contains(env.BRANCH_NAME)) {
    echo "Building master branch."
  } else {
    input "Do you want to test this change?"
  }

  stage "Build containers"
  wrap([$class: 'AnsiColorBuildWrapper', 'colorMapName': 'XTerm']) {
    withEnv([ "BRANCH_NAME=${env.BRANCH_NAME}",
              "CHANGE_TARGET=${env.CHANGE_TARGET}"]) {
      dir ("docks") {
        withCredentials([[$class: 'UsernamePasswordMultiBinding',
                          credentialsId: '75206d40-8dcf-4f44-aea4-e3a32bc201b3',
                          usernameVariable: 'DOCK_USER',
                          passwordVariable: 'DOCK_PASSWORD']]) {
          retry(2) {
            timeout(900) {
              checkout scm
              sh '''
                set -e
                set -o pipefail
                packer version
                GIT_DIFF_SRC="origin/$CHANGE_TARGET"
                [[ $CHANGE_TARGET == null || -z $CHANGE_TARGET ]] && GIT_DIFF_SRC="HEAD^"
                IMAGES=`git diff --name-only $GIT_DIFF_SRC.. | (grep / || true) | sed -e 's|/.*||' | uniq`
                case $BRANCH_NAME in
                  master) DOCKER_HUB_REPO=alisw    ;;
                  *)      DOCKER_HUB_REPO=aliswdev ;;
                esac
                export PACKER_LOG=1
                export PACKER_LOG_PATH=$PWD/packer.log
                mkdir -p /build/packer && [[ -d /build/packer ]]
                export TMPDIR=$(mktemp -d /build/packer/packer-XXXXX)
                export HOME=$TMPDIR
                yes | docker login -u "$DOCK_USER" -p "$DOCK_PASSWORD" || true
                unset DOCK_USER DOCK_PASSWORD
                for x in $IMAGES ; do
                  if ! test -f $x/packer.json ; then
                    echo "Image $x does not use Packer, skipping test."
                    continue
                  elif grep DOCKER_HUB_REPO "$x/packer.json" ; then
                    pushd "$x"
                     /usr/bin/packer build -var "DOCKER_HUB_REPO=${DOCKER_HUB_REPO}" packer.json || { cat $PACKER_LOG_PATH; false; }
                     echo "Image $x built successfully and uploaded as $DOCKER_HUB_REPO/$x"
                    popd
                  else
                    echo "$x/packer.json does not use DOCKER_HUB_REPO."
                    exit 1
                  fi
                done
              '''
            }
          }
        }
      }
    }
  }
}


// library('declarative-libs') pipeline { parameters { string(name: 'String parameter with spaces', defaultValue: 'Fill me in with something witty!', description: 'This is a string parameter, yo!') booleanParam(name: 'TRUE_OR_FALSE', defaultValue: true, description: 'This boolean defaults to true!') string(name: 'AGENT_NAME', defaultValue: 'linux', description: 'Where to run') } agent { label ("${env.AGENT_NAME}") } environment { SOMETHING_TO_INHERIT = "This has been inherited!" SOMETHING_TO_OVERRIDE = "This should be overriden, if you see it, that's wrong." } options { buildDiscarder(logRotator(numToKeepStr: '100')) disableConcurrentBuilds() timestamps() } triggers { pollSCM('*/10 * * * *') } tools { jdk 'jdk8' } stages { stage ('Parallel Wrapper') { // start of parallel wrapper parallel { stage('parallel-1') { steps { echo "--> AGENT_NAME is ${env.AGENT_NAME} " echo "--> What version of java?" sh "java -version" } } stage('parallel-2 overrides environment variables') { agent { label 'linux' } environment { SOMETHING_TO_OVERRIDE = "YES --> Overridden by parallel-2" } tools { jdk 'jdk7' } steps { echo "--> What version of java?" sh "java -version" echo "Let's check our environment variables" echo SOMETHING_TO_INHERIT echo SOMETHING_TO_OVERRIDE } } stage('parallel-3 back to jdk8') { environment { SOMETHING_TO_OVERRIDE = "YES --> OVERRIDDEN BY PARALLEL-3" } tools { jdk 'jdk8' } steps { echo "--> What version of java?" sh "java -version" echo "Let's check our environment variables" echo SOMETHING_TO_INHERIT echo SOMETHING_TO_OVERRIDE } } stage('parallel-4 back to jdk7') { environment { SOMETHING_TO_OVERRIDE = "YES --> OVERRIDDEN BY PARALLEL-4" } tools { jdk 'jdk7' } steps { echo "--> What version of java?" sh "java -version" echo "Let's check our environment variables" echo SOMETHING_TO_INHERIT echo SOMETHING_TO_OVERRIDE } } stage('parallel-5 back to jdk8') { environment { SOMETHING_TO_OVERRIDE = "YES --> OVERRIDDEN BY PARALLEL-5" } tools { jdk 'jdk8' } steps { echo "--> What version of java?" sh "java -version" echo "Let's check our environment variables" echo SOMETHING_TO_INHERIT echo SOMETHING_TO_OVERRIDE } } } // end of parallel } // end of wrapper stage } // end stages post { always { echo "ALWAYS --> Runs all the time." } success { echo "SUCCESS --> Whatever we did, it worked. Yay!" } failure { echo "FAILURE --> Failed. Womp womp." } } }



https://github.com/Mirantis/pipeline-library/blob/master/src/com/mirantis/mk/Common.groovy


Skip to content
Why GitHub? 
Enterprise
Explore 
Marketplace
Pricing 
Search

Sign in
Sign up
12 40 42 Mirantis/pipeline-library
 Code  Issues 1  Pull requests 1  Projects 0  Insights
Join GitHub today
GitHub is home to over 36 million developers working together to host and review code, manage projects, and build software together.

pipeline-library/src/com/mirantis/mk/Common.groovy
@degorenko degorenko Add archivation for comparePillars func
6212096 on 15 Mar
@jakubjosef @alexz-kh @degorenko @jumpojoy @tomkukral @Martin819 @fpytloun @vryzhenkin @sandriichenko @r0mik @richardfelkl @mceloud @dmi-try @chnyda
1008 lines (933 sloc)  31.9 KB
    
package com.mirantis.mk

import static groovy.json.JsonOutput.prettyPrint
import static groovy.json.JsonOutput.toJson

import com.cloudbees.groovy.cps.NonCPS
import groovy.json.JsonSlurperClassic

/**
 *
 * Common functions
 *
 */

/**
 * Generate current timestamp
 *
 * @param format Defaults to yyyyMMddHHmmss
 */
def getDatetime(format = "yyyyMMddHHmmss") {
    def now = new Date();
    return now.format(format, TimeZone.getTimeZone('UTC'));
}

/**
 * Return workspace.
 * Currently implemented by calling pwd so it won't return relevant result in
 * dir context
 */
def getWorkspace(includeBuildNum = false) {
    def workspace = sh script: 'pwd', returnStdout: true
    workspace = workspace.trim()
    if (includeBuildNum) {
        if (!workspace.endsWith("/")) {
            workspace += "/"
        }
        workspace += env.BUILD_NUMBER
    }
    return workspace
}

/**
 * Get UID of jenkins user.
 * Must be run from context of node
 */
def getJenkinsUid() {
    return sh(
        script: 'id -u',
        returnStdout: true
    ).trim()
}

/**
 * Get GID of jenkins user.
 * Must be run from context of node
 */
def getJenkinsGid() {
    return sh(
        script: 'id -g',
        returnStdout: true
    ).trim()
}

/**
 * Returns Jenkins user uid and gid in one list (in that order)
 * Must be run from context of node
 */
def getJenkinsUserIds() {
    return sh(script: "id -u && id -g", returnStdout: true).tokenize("\n")
}

/**
 *
 * Find credentials by ID
 *
 * @param credsId Credentials ID
 * @param credsType Credentials type (optional)
 *
 */
def getCredentialsById(String credsId, String credsType = 'any') {
    def credClasses = [ // ordered by class name
                        sshKey    : com.cloudbees.jenkins.plugins.sshcredentials.impl.BasicSSHUserPrivateKey.class,
                        cert      : com.cloudbees.plugins.credentials.common.CertificateCredentials.class,
                        password  : com.cloudbees.plugins.credentials.common.StandardUsernamePasswordCredentials.class,
                        any       : com.cloudbees.plugins.credentials.impl.BaseStandardCredentials.class,
                        dockerCert: org.jenkinsci.plugins.docker.commons.credentials.DockerServerCredentials.class,
                        file      : org.jenkinsci.plugins.plaincredentials.FileCredentials.class,
                        string    : org.jenkinsci.plugins.plaincredentials.StringCredentials.class,
    ]
    return com.cloudbees.plugins.credentials.CredentialsProvider.lookupCredentials(
        credClasses[credsType],
        jenkins.model.Jenkins.instance
    ).findAll { cred -> cred.id == credsId }[0]
}

/**
 * Get credentials from store
 *
 * @param id Credentials name
 */
def getCredentials(id, cred_type = "username_password") {
    warningMsg('You are using obsolete function. Please switch to use `getCredentialsById()`')

    type_map = [
        username_password: 'password',
        key              : 'sshKey',
    ]

    return getCredentialsById(id, type_map[cred_type])
}

/**
 * Abort build, wait for some time and ensure we will terminate
 */
def abortBuild() {
    currentBuild.build().doStop()
    sleep(180)
    // just to be sure we will terminate
    throw new InterruptedException()
}

/**
 * Print pretty-printed string representation of given item
 * @param item item to be pretty-printed (list, map, whatever)
 */
def prettyPrint(item) {
    println prettify(item)
}

/**
 * Return pretty-printed string representation of given item
 * @param item item to be pretty-printed (list, map, whatever)
 * @return pretty-printed string
 */
def prettify(item) {
    return groovy.json.JsonOutput.prettyPrint(toJson(item)).replace('\\n', System.getProperty('line.separator'))
}

/**
 * Print informational message
 *
 * @param msg
 * @param color Colorful output or not
 */
def infoMsg(msg, color = true) {
    printMsg(msg, "cyan")
}

/**
 * Print error message
 *
 * @param msg
 * @param color Colorful output or not
 */
def errorMsg(msg, color = true) {
    printMsg(msg, "red")
}

/**
 * Print success message
 *
 * @param msg
 * @param color Colorful output or not
 */
def successMsg(msg, color = true) {
    printMsg(msg, "green")
}

/**
 * Print warning message
 *
 * @param msg
 * @param color Colorful output or not
 */
def warningMsg(msg, color = true) {
    printMsg(msg, "yellow")
}

/**
 * Print debug message, this message will show only if DEBUG global variable is present
 * @param msg
 * @param color Colorful output or not
 */
def debugMsg(msg, color = true) {
    // if debug property exists on env, debug is enabled
    if (env.getEnvironment().containsKey('DEBUG') && env['DEBUG'] == "true") {
        printMsg("[DEBUG] ${msg}", "red")
    }
}

def getColorizedString(msg, color) {
    def colorMap = [
        'red'   : '\u001B[31m',
        'black' : '\u001B[30m',
        'green' : '\u001B[32m',
        'yellow': '\u001B[33m',
        'blue'  : '\u001B[34m',
        'purple': '\u001B[35m',
        'cyan'  : '\u001B[36m',
        'white' : '\u001B[37m',
        'reset' : '\u001B[0m'
    ]

    return "${colorMap[color]}${msg}${colorMap.reset}"
}

/**
 * Print message
 *
 * @param msg Message to be printed
 * @param color Color to use for output
 */
def printMsg(msg, color) {
    print getColorizedString(msg, color)
}

/**
 * Traverse directory structure and return list of files
 *
 * @param path Path to search
 * @param type Type of files to search (groovy.io.FileType.FILES)
 */
@NonCPS
def getFiles(path, type = groovy.io.FileType.FILES) {
    files = []
    new File(path).eachFile(type) {
        files[] = it
    }
    return files
}

/**
 * Helper method to convert map into form of list of [key,value] to avoid
 * unserializable exceptions
 *
 * @param m Map
 */
@NonCPS
def entries(m) {
    m.collect { k, v -> [k, v] }
}

/**
 * Opposite of build-in parallel, run map of steps in serial
 *
 * @param steps Map of String<name>: CPSClosure2<step> (or list of closures)
 */
def serial(steps) {
    stepsArray = entries(steps)
    for (i = 0; i < stepsArray.size; i++) {
        def step = stepsArray[i]
        def dummySteps = [:]
        def stepKey
        if (step[1] instanceof List || step[1] instanceof Map) {
            for (j = 0; j < step[1].size(); j++) {
                if (step[1] instanceof List) {
                    stepKey = j
                } else if (step[1] instanceof Map) {
                    stepKey = step[1].keySet()[j]
                }
                dummySteps.put("step-${step[0]}-${stepKey}", step[1][stepKey])
            }
        } else {
            dummySteps.put(step[0], step[1])
        }
        parallel dummySteps
    }
}

/**
 * Partition given list to list of small lists
 * @param inputList input list
 * @param partitionSize (partition size, optional, default 5)
 */
def partitionList(inputList, partitionSize = 5) {
    List<List<String>> partitions = new ArrayList<>();
    for (int i = 0; i < inputList.size(); i += partitionSize) {
        partitions.add(new ArrayList<String>(inputList.subList(i, Math.min(i + partitionSize, inputList.size()))));
    }
    return partitions
}

/**
 * Get password credentials from store
 *
 * @param id Credentials name
 */
def getPasswordCredentials(id) {
    return getCredentialsById(id, 'password')
}

/**
 * Get SSH credentials from store
 *
 * @param id Credentials name
 */
def getSshCredentials(id) {
    return getCredentialsById(id, 'sshKey')
}

/**
 * Tests Jenkins instance for existence of plugin with given name
 * @param pluginName plugin short name to test
 * @return boolean result
 */
@NonCPS
def jenkinsHasPlugin(pluginName) {
    return Jenkins.instance.pluginManager.plugins.collect { p -> p.shortName }.contains(pluginName)
}

@NonCPS
def _needNotification(notificatedTypes, buildStatus, jobName) {
    if (notificatedTypes && notificatedTypes.contains("onchange")) {
        if (jobName) {
            def job = Jenkins.instance.getItem(jobName)
            def numbuilds = job.builds.size()
            if (numbuilds > 0) {
                //actual build is first for some reasons, so last finished build is second
                def lastBuild = job.builds[1]
                if (lastBuild) {
                    if (lastBuild.result.toString().toLowerCase().equals(buildStatus)) {
                        println("Build status didn't changed since last build, not sending notifications")
                        return false;
                    }
                }
            }
        }
    } else if (!notificatedTypes.contains(buildStatus)) {
        return false;
    }
    return true;
}

/**
 * Send notification to all enabled notifications services
 * @param buildStatus message type (success, warning, error), null means SUCCESSFUL
 * @param msgText message text
 * @param enabledNotifications list of enabled notification types, types: slack, hipchat, email, default empty
 * @param notificatedTypes types of notifications will be sent, default onchange - notificate if current build result not equal last result;
 *                         otherwise use - ["success","unstable","failed"]
 * @param jobName optional job name param, if empty env.JOB_NAME will be used
 * @param buildNumber build number param, if empty env.BUILD_NUM will be used
 * @param buildUrl build url param, if empty env.BUILD_URL will be used
 * @param mailFrom mail FROM param, if empty "jenkins" will be used, it's mandatory for sending email notifications
 * @param mailTo mail TO param, it's mandatory for sending email notifications, this option enable mail notification
 */
def sendNotification(buildStatus, msgText = "", enabledNotifications = [], notificatedTypes = ["onchange"], jobName = null, buildNumber = null, buildUrl = null, mailFrom = "jenkins", mailTo = null) {
    // Default values
    def colorName = 'blue'
    def colorCode = '#0000FF'
    def buildStatusParam = buildStatus != null && buildStatus != "" ? buildStatus : "SUCCESS"
    def jobNameParam = jobName != null && jobName != "" ? jobName : env.JOB_NAME
    def buildNumberParam = buildNumber != null && buildNumber != "" ? buildNumber : env.BUILD_NUMBER
    def buildUrlParam = buildUrl != null && buildUrl != "" ? buildUrl : env.BUILD_URL
    def subject = "${buildStatusParam}: Job '${jobNameParam} [${buildNumberParam}]'"
    def summary = "${subject} (${buildUrlParam})"

    if (msgText != null && msgText != "") {
        summary += "\n${msgText}"
    }
    if (buildStatusParam.toLowerCase().equals("success")) {
        colorCode = "#00FF00"
        colorName = "green"
    } else if (buildStatusParam.toLowerCase().equals("unstable")) {
        colorCode = "#FFFF00"
        colorName = "yellow"
    } else if (buildStatusParam.toLowerCase().equals("failure")) {
        colorCode = "#FF0000"
        colorName = "red"
    }
    if (_needNotification(notificatedTypes, buildStatusParam.toLowerCase(), jobNameParam)) {
        if (enabledNotifications.contains("slack") && jenkinsHasPlugin("slack")) {
            try {
                slackSend color: colorCode, message: summary
            } catch (Exception e) {
                println("Calling slack plugin failed")
                e.printStackTrace()
            }
        }
        if (enabledNotifications.contains("hipchat") && jenkinsHasPlugin("hipchat")) {
            try {
                hipchatSend color: colorName.toUpperCase(), message: summary
            } catch (Exception e) {
                println("Calling hipchat plugin failed")
                e.printStackTrace()
            }
        }
        if (enabledNotifications.contains("email") && mailTo != null && mailTo != "" && mailFrom != null && mailFrom != "") {
            try {
                mail body: summary, from: mailFrom, subject: subject, to: mailTo
            } catch (Exception e) {
                println("Sending mail plugin failed")
                e.printStackTrace()
            }
        }
    }
}

/**
 * Execute linux command and catch nth element
 * @param cmd command to execute
 * @param index index to retrieve
 * @return index-th element
 */

def cutOrDie(cmd, index) {
    def common = new com.mirantis.mk.Common()
    def output
    try {
        output = sh(script: cmd, returnStdout: true)
        def result = output.tokenize(" ")[index]
        return result;
    } catch (Exception e) {
        common.errorMsg("Failed to execute cmd: ${cmd}\n output: ${output}")
    }
}

/**
 * Check variable contains keyword
 * @param variable keywork is searched (contains) here
 * @param keyword string to look for
 * @return True if variable contains keyword (case insensitive), False if do not contains or any of input isn't a string
 */

def checkContains(variable, keyword) {
    if (env.getEnvironment().containsKey(variable)) {
        return env[variable] && env[variable].toLowerCase().contains(keyword.toLowerCase())
    } else {
        return false
    }
}

/**
 * Parse JSON string to hashmap
 * @param jsonString input JSON string
 * @return created hashmap
 */
def parseJSON(jsonString) {
    def m = [:]
    def lazyMap = new JsonSlurperClassic().parseText(jsonString)
    m.putAll(lazyMap)
    return m
}

/**
 *
 * Deep merge of  Map items. Merges variable number of maps in to onto.
 *   Using the following rules:
 *     - Lists are appended
 *     - Maps are updated
 *     - other object types are replaced.
 *
 *
 * @param onto Map object to merge in
 * @param overrides Map objects to merge to onto
*/
def mergeMaps(Map onto, Map... overrides){
    if (!overrides){
        return onto
    }
    else if (overrides.length == 1) {
        overrides[0]?.each { k, v ->
            if (v in Map && onto[k] in Map){
                mergeMaps((Map) onto[k], (Map) v)
            } else if (v in List) {
                onto[k] += v
            } else {
                onto[k] = v
            }
        }
        return onto
    }
    return overrides.inject(onto, { acc, override -> mergeMaps(acc, override ?: [:]) })
}

/**
 * Test pipeline input parameter existence and validity (not null and not empty string)
 * @param paramName input parameter name (usually uppercase)
  */
def validInputParam(paramName) {
    if (paramName instanceof java.lang.String) {
        return env.getEnvironment().containsKey(paramName) && env[paramName] != null && env[paramName] != ""
    }
    return false
}

/**
 * Take list of hashmaps and count number of hashmaps with parameter equals eq
 * @param lm list of hashmaps
 * @param param define parameter of hashmap to read and compare
 * @param eq desired value of hashmap parameter
 * @return count of hashmaps meeting defined condition
 */

@NonCPS
def countHashMapEquals(lm, param, eq) {
    return lm.stream().filter { i -> i[param].equals(eq) }.collect(java.util.stream.Collectors.counting())
}

/**
 * Execute shell command and return stdout, stderr and status
 *
 * @param cmd Command to execute
 * @return map with stdout, stderr, status keys
 */

def shCmdStatus(cmd) {
    def res = [:]
    def stderr = sh(script: 'mktemp', returnStdout: true).trim()
    def stdout = sh(script: 'mktemp', returnStdout: true).trim()

    try {
        def status = sh(script: "${cmd} 1>${stdout} 2>${stderr}", returnStatus: true)
        res['stderr'] = sh(script: "cat ${stderr}", returnStdout: true)
        res['stdout'] = sh(script: "cat ${stdout}", returnStdout: true)
        res['status'] = status
    } finally {
        sh(script: "rm ${stderr}", returnStdout: true)
        sh(script: "rm ${stdout}", returnStdout: true)
    }

    return res
}

/**
 * Retry commands passed to body
 *
 * Don't use common.retry method for retrying salt.enforceState method. Use retries parameter
 * built-in the salt.enforceState method instead to ensure correct functionality.
 *
 * @param times Number of retries
 * @param delay Delay between retries (in seconds)
 * @param body Commands to be in retry block
 * @return calling commands in body
 * @example retry ( 3 , 5 ) { function body }*          retry{ function body }
 */

def retry(int times = 5, int delay = 0, Closure body) {
    int retries = 0
    while (retries++ < times) {
        try {
            return body.call()
        } catch (e) {
            errorMsg(e.toString())
            sleep(delay)
        }
    }
    throw new Exception("Failed after $times retries")
}

/**
 * Wait for user input with timeout
 *
 * @param timeoutInSeconds Timeout
 * @param options Options for input widget
 */
def waitForInputThenPass(timeoutInSeconds, options = [message: 'Ready to go?']) {
    def userInput = true
    try {
        timeout(time: timeoutInSeconds, unit: 'SECONDS') {
            userInput = input options
        }
    } catch (err) { // timeout reached or input false
        def user = err.getCauses()[0].getUser()
        if ('SYSTEM' == user.toString()) { // SYSTEM means timeout.
            println("Timeout, proceeding")
        } else {
            userInput = false
            println("Aborted by: [${user}]")
            throw err
        }
    }
    return userInput
}

/**
 * Function receives Map variable as input and sorts it
 * by values ascending. Returns sorted Map
 * @param _map Map variable
 */
@NonCPS
def SortMapByValueAsc(_map) {
    def sortedMap = _map.sort { it.value }
    return sortedMap
}

/**
 *  Compare 'old' and 'new' dir's recursively
 * @param diffData =' Only in new/XXX/infra: secrets.yml
 Files old/XXX/init.yml and new/XXX/init.yml differ
 Only in old/XXX/infra: secrets11.yml '
 *
 * @return
 *   - new:
 - XXX/secrets.yml
 - diff:
 - XXX/init.yml
 - removed:
 - XXX/secrets11.yml
 */
def diffCheckMultidir(diffData) {
    common = new com.mirantis.mk.Common()
    // Some global constants. Don't change\move them!
    keyNew = 'new'
    keyRemoved = 'removed'
    keyDiff = 'diff'
    def output = [
        new    : [],
        removed: [],
        diff   : [],
    ]
    String pathSep = '/'
    diffData.each { line ->
        def job_file = ''
        def job_type = ''
        if (line.startsWith('Files old/')) {
            job_file = new File(line.replace('Files old/', '').tokenize()[0])
            job_type = keyDiff
        } else if (line.startsWith('Only in new/')) {
            // get clean normalized filepath, under new/
            job_file = new File(line.replace('Only in new/', '').replace(': ', pathSep)).toString()
            job_type = keyNew
        } else if (line.startsWith('Only in old/')) {
            // get clean normalized filepath, under old/
            job_file = new File(line.replace('Only in old/', '').replace(': ', pathSep)).toString()
            job_type = keyRemoved
        } else {
            common.warningMsg("Not parsed diff line: ${line}!")
        }
        if (job_file != '') {
            output[job_type].push(job_file)
        }
    }
    return output
}

/**
 * Compare 2 folder, file by file
 * Structure should be:
 * ${compRoot}/
 └── diff - diff results will be save here
 ├── new  - input folder with data
 ├── old  - input folder with data
 ├── pillar.diff - globall diff will be saved here
 * b_url - usual env.BUILD_URL, to be add into description
 * grepOpts -   General grep cmdline; Could be used to pass some magic
 *              regexp into after-diff listing file(pillar.diff)
 *              Example: '-Ev infra/secrets.yml'
 * return - html-based string
 * TODO: allow to specify subdir for results?
 **/

def comparePillars(compRoot, b_url, grepOpts) {

    // Some global constants. Don't change\move them!
    keyNew = 'new'
    keyRemoved = 'removed'
    keyDiff = 'diff'
    def diff_status = 0
    // FIXME
    httpWS = b_url + '/artifact/'
    dir(compRoot) {
        // If diff empty - exit 0
        diff_status = sh(script: 'diff -q -r old/ new/  > pillar.diff',
            returnStatus: true,
        )
    }
    // Unfortunately, diff not able to work with dir-based regexp
    if (diff_status == 1 && grepOpts) {
        dir(compRoot) {
            grep_status = sh(script: """
                cp -v pillar.diff pillar_orig.diff
                grep ${grepOpts} pillar_orig.diff  > pillar.diff
                """,
                returnStatus: true
            )
            if (grep_status == 1) {
                warningMsg("Grep regexp ${grepOpts} removed all diff!")
                diff_status = 0
            }
        }
    }
    // Set job description
    description = ''
    if (diff_status == 1) {
        // Analyse output file and prepare array with results
        String data_ = readFile file: "${compRoot}/pillar.diff"
        def diff_list = diffCheckMultidir(data_.split("\\r?\\n"))
        infoMsg(diff_list)
        dir(compRoot) {
            if (diff_list[keyDiff].size() > 0) {
                if (!fileExists('diff')) {
                    sh('mkdir -p diff')
                }
                description += '<b>CHANGED</b><ul>'
                infoMsg('Changed items:')
                def stepsForParallel = [:]
                stepsForParallel.failFast = true
                diff_list[keyDiff].each {
                    stepsForParallel.put("Differ for:${it}",
                        {
                            // We don't want to handle sub-dirs structure. So, simply make diff 'flat'
                            def item_f = it.toString().replace('/', '_')
                            description += "<li><a href=\"${httpWS}/diff/${item_f}/*view*/\">${it}</a></li>"
                            // Generate diff file
                            def diff_exit_code = sh([
                                script      : "diff -U 50 old/${it} new/${it} > diff/${item_f}",
                                returnStdout: false,
                                returnStatus: true,
                            ])
                            // catch normal errors, diff should always return 1
                            if (diff_exit_code != 1) {
                                error 'Error with diff file generation'
                            }
                        })
                }

                parallel stepsForParallel
            }
            if (diff_list[keyNew].size() > 0) {
                description += '<b>ADDED</b><ul>'
                for (item in diff_list[keyNew]) {
                    description += "<li><a href=\"${httpWS}/new/${item}/*view*/\">${item}</a></li>"
                }
            }
            if (diff_list[keyRemoved].size() > 0) {
                description += '<b>DELETED</b><ul>'
                for (item in diff_list[keyRemoved]) {
                    description += "<li><a href=\"${httpWS}/old/${item}/*view*/\">${item}</a></li>"
                }
            }
            def cwd = sh(script: 'basename $(pwd)', returnStdout: true).trim()
            sh "tar -cf old_${cwd}.tar.gz old/ && rm -rf old/"
            sh "tar -cf new_${cwd}.tar.gz new/ && rm -rf new/"
        }
    }

    if (description != '') {
        dir(compRoot) {
            archiveArtifacts([
                artifacts        : '**',
                allowEmptyArchive: true,
            ])
        }
        return description.toString()
    } else {
        return '<b>No job changes</b>'
    }
}

/**
 * Simple function, to get basename from string.
 * line - path-string
 * remove_ext - string, optionl. Drop file extenstion.
 **/
def GetBaseName(line, remove_ext) {
    filename = line.toString().split('/').last()
    if (remove_ext && filename.endsWith(remove_ext.toString())) {
        filename = filename.take(filename.lastIndexOf(remove_ext.toString()))
    }
    return filename
}

/**
 * Return colored string of specific stage in stageMap
 *
 * @param stageMap LinkedHashMap object.
 * @param stageName The name of current stage we are going to execute.
 * @param color Text color
 * */
def getColoredStageView(stageMap, stageName, color) {
    def stage = stageMap[stageName]
    def banner = []
    def currentStageIndex = new ArrayList<String>(stageMap.keySet()).indexOf(stageName)
    def numberOfStages = stageMap.keySet().size() - 1

    banner.add(getColorizedString(
        "=========== Stage ${currentStageIndex}/${numberOfStages}: ${stageName} ===========", color))
    for (stage_item in stage.keySet()) {
        banner.add(getColorizedString(
            "${stage_item}: ${stage[stage_item]}", color))
    }
    banner.add('\n')

    return banner
}

/**
 * Pring stageMap to console with specified color
 *
 * @param stageMap LinkedHashMap object with stages information.
 * @param currentStage The name of current stage we are going to execute.
 *
 * */
def printCurrentStage(stageMap, currentStage) {
    print getColoredStageView(stageMap, currentStage, "cyan").join('\n')
}

/**
 * Pring stageMap to console with specified color
 *
 * @param stageMap LinkedHashMap object.
 * @param baseColor Text color (default white)
 * */
def printStageMap(stageMap, baseColor = "white") {
    def banner = []
    def index = 0
    for (stage_name in stageMap.keySet()) {
        banner.addAll(getColoredStageView(stageMap, stage_name, baseColor))
    }
    print banner.join('\n')
}

/**
 * Wrap provided code in stage, and do interactive retires if needed.
 *
 * @param stageMap LinkedHashMap object with stages information.
 * @param currentStage The name of current stage we are going to execute.
 * @param target Target host to execute stage on.
 * @param interactive Boolean flag to specify if interaction with user is enabled.
 * @param body Command to be in stage block.
 * */
def stageWrapper(stageMap, currentStage, target, interactive = true, Closure body) {
    def common = new com.mirantis.mk.Common()
    def banner = []

    printCurrentStage(stageMap, currentStage)

    stage(currentStage) {
      if (interactive){
        input message: getColorizedString("We are going to execute stage \'${currentStage}\' on the following target ${target}.\nPlease review stage information above.", "yellow")
      }
      try {
        stageMap[currentStage]['Status'] = "SUCCESS"
        return body.call()
      } catch (Exception err) {
        def msg = "Stage ${currentStage} failed with the following exception:\n${err}"
        print getColorizedString(msg, "yellow")
        common.errorMsg(err)
        if (interactive) {
          input message: getColorizedString("Please make sure problem is fixed to proceed with retry. Ready to proceed?", "yellow")
          stageMap[currentStage]['Status'] = "RETRYING"
          stageWrapper(stageMap, currentStage, target, interactive, body)
        } else {
          error(msg)
        }
      }
    }
}

/**
 *  Ugly transition solution for internal tests.
 *  1) Check input => transform to static result, based on runtime and input
 *  2) Check remote-binary repo for exact resource
 *  Return: changes each linux_system_* cto false, in case broken url in some of them
  */

def checkRemoteBinary(LinkedHashMap config, List extraScmExtensions = []) {
    def common = new com.mirantis.mk.Common()
    def res = [:]
    res['MirrorRoot'] = config.get('globalMirrorRoot', env["BIN_MIRROR_ROOT"] ? env["BIN_MIRROR_ROOT"] : "http://mirror.mirantis.com/")
    // Reclass-like format's. To make life eazy!
    res['mcp_version'] = config.get('mcp_version', env["BIN_APT_MCP_VERSION"] ? env["BIN_APT_MCP_VERSION"] : 'nightly')
    res['linux_system_repo_url'] = config.get('linux_system_repo_url', env['BIN_linux_system_repo_url'] ? env['BIN_linux_system_repo_url'] : "${res['MirrorRoot']}/${res['mcp_version']}/")
    res['linux_system_repo_ubuntu_url'] = config.get('linux_system_repo_ubuntu_url', env['BIN_linux_system_repo_ubuntu_url'] ? env['BIN_linux_system_repo_ubuntu_url'] : "${res['MirrorRoot']}/${res['mcp_version']}/ubuntu/")
    res['linux_system_repo_mcp_salt_url'] = config.get('linux_system_repo_mcp_salt_url', env['BIN_linux_system_repo_mcp_salt_url'] ? env['BIN_linux_system_repo_mcp_salt_url'] : "${res['MirrorRoot']}/${res['mcp_version']}/salt-formulas/")

    if (config.get('verify', true)) {
        res.each { key, val ->
            if (key.toString().startsWith('linux_system_repo')) {
                def MirrorRootStatus = sh(script: "wget  --auth-no-challenge --spider ${val} 2>/dev/null", returnStatus: true)
                if (MirrorRootStatus != 0) {
                    common.warningMsg("Resource: '${key}' at '${val}' not exist!")
                    res[key] = false
                }
            }
        }
    }
    return res
}

/**
 *  Workaround to update env properties, like GERRIT_* vars,
 *  which should be passed from upstream job to downstream.
 *  Will not fail entire job in case any issues.
 *  @param envVar - EnvActionImpl env job
 *  @param extraVars - Multiline YAML text with extra vars
 */
def mergeEnv(envVar, extraVars) {
    def common = new com.mirantis.mk.Common()
    try {
        def extraParams = readYaml text: extraVars
        for(String key in extraParams.keySet()) {
            envVar[key] = extraParams[key]
            common.warningMsg("Parameter ${key} is updated from EXTRA vars.")
        }
    } catch (Exception e) {
        common.errorMsg("Can't update env parameteres, because: ${e.toString()}")
    }
}

/**
 * Wrapper around parallel pipeline function
 * with ability to restrict number of parallel threads
 * running simultaneously
 *
 * @param branches - Map with Clousers to be executed
 * @param maxParallelJob - Integer number of parallel threads allowed
 *                         to run simultaneously
 */
def runParallel(branches, maxParallelJob = 10) {
    def runningSteps = 0
    branches.each { branchName, branchBody ->
        if (branchBody instanceof Closure) {
            branches[branchName] = {
                while (!(runningSteps < maxParallelJob)) {
                    continue
                }
                runningSteps += 1
                branchBody.call()
                runningSteps -= 1
            }
        }
    }
    if (branches) {
        parallel branches
    }
}

/**
 * Ugly processing basic funcs with /etc/apt
 * @param repoConfig YAML text or Map
 * Example :
 repoConfig = '''
 ---
 aprConfD: |-
   APT::Get::AllowUnauthenticated 'true';
 repo:
   mcp_saltstack:
     source: "deb [arch=amd64] http://mirror.mirantis.com/nightly/saltstack-2017.7/xenial xenial main"
     pin:
       - package: "libsodium18"
         pin: "release o=SaltStack"
         priority: 50
       - package: "*"
         pin: "release o=SaltStack"
         priority: "1100"
     repo_key: "http://mirror.mirantis.com/public.gpg"
 '''
 *
 */

def debianExtraRepos(repoConfig) {
    def config = null
    if (repoConfig instanceof Map) {
        config = repoConfig
    } else {
        config = readYaml text: repoConfig
    }
    if (config.get('repo', false)) {
        for (String repo in config['repo'].keySet()) {
            source = config['repo'][repo]['source']
            warningMsg("Write ${source} >  /etc/apt/sources.list.d/${repo}.list")
            sh("echo '${source}' > /etc/apt/sources.list.d/${repo}.list")
            if (config['repo'][repo].containsKey('repo_key')) {
                key = config['repo'][repo]['repo_key']
                sh("wget -O - '${key}' | apt-key add -")
            }
            if (config['repo'][repo]['pin']) {
                def repoPins = []
                for (Map pin in config['repo'][repo]['pin']) {
                    repoPins.add("Package: ${pin['package']}")
                    repoPins.add("Pin: ${pin['pin']}")
                    repoPins.add("Pin-Priority: ${pin['priority']}")
                    // additional empty line between pins
                    repoPins.add('\n')
                }
                if (repoPins) {
                    repoPins.add(0, "### Extra ${repo} repo pin start ###")
                    repoPins.add("### Extra ${repo} repo pin end ###")
                    repoPinning = repoPins.join('\n')
                    warningMsg("Adding pinning \n${repoPinning}\n => /etc/apt/preferences.d/${repo}")
                    sh("echo '${repoPinning}' > /etc/apt/preferences.d/${repo}")
                }
            }
        }
    }
    if (config.get('aprConfD', false)) {
        for (String pref in config['aprConfD'].tokenize('\n')) {
            warningMsg("Adding ${pref} => /etc/apt/apt.conf.d/99setupAndTestNode")
            sh("echo '${pref}' >> /etc/apt/apt.conf.d/99setupAndTestNode")
        }
        sh('cat /etc/apt/apt.conf.d/99setupAndTestNode')
    }
}

/**
 * Parse date from string
 * @param String date - date to parse
 * @param String format - date format in provided date string value
 *
 * return new Date() object
 */
Date parseDate(String date, String format) {
    return Date.parse(format, date)
}
© 2019 GitHub, Inc.
Terms
Privacy
Security
Status
Help
Contact GitHub
Pricing
API
Training
Blog
About
