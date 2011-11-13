require 'ant'

begin
  # will work from gem, since lib dir is in gem require_paths
  require 'red_storm'
rescue LoadError
  # will work within RedStorm dev project
  $:.unshift './lib'
  require 'red_storm'
end

CWD = Dir.pwd
TARGET_DIR = "#{CWD}/target"
TARGET_SRC_DIR = "#{TARGET_DIR}/src"
TARGET_CLASSES_DIR = "#{TARGET_DIR}/classes"  
TARGET_DEPENDENCY_DIR = "#{TARGET_DIR}/dependency"
TARGET_DEPENDENCY_UNPACKED_DIR = "#{TARGET_DIR}/dependency-unpacked"
TARGET_CLUSTER_JAR = "#{TARGET_DIR}/cluster-topology.jar"

JAVA_SRC_DIR = "#{RedStorm::REDSTORM_HOME}/src/main"
JRUBY_SRC_DIR = "#{RedStorm::REDSTORM_HOME}/lib/red_storm"

SRC_EXAMPLES = "#{RedStorm::REDSTORM_HOME}/examples"
DST_EXAMPLES = "#{CWD}/examples"

task :launch, :env, :class_file do |t, args|
  gem_home = ENV["GEM_HOME"].to_s.empty? ? " -Djruby.gem.home=`gem env home`" : ""
  command = "java -cp \"#{TARGET_CLASSES_DIR}:#{TARGET_DEPENDENCY_DIR}/*\"#{gem_home} redstorm.TopologyLauncher #{args[:env]} #{args[:class_file]}"
  puts("launching #{command}")
  system(command)
end

task :clean do
  ant.delete :dir => TARGET_DIR
end

task :clean_jar do
  ant.delete :dir => "#{TARGET_DIR}/cluster-topology.jar"
end

task :setup do  
  ant.mkdir :dir => TARGET_DIR 
  ant.mkdir :dir => TARGET_CLASSES_DIR 
  ant.mkdir :dir => TARGET_SRC_DIR
  ant.path :id => 'classpath' do  
    fileset :dir => TARGET_DEPENDENCY_DIR  
    fileset :dir => TARGET_CLASSES_DIR  
  end  
end

task :install => [:deps, :build] do
  puts("\nRedStorm install completed. All dependencies installed in #{TARGET_DIR}")
end

task :unpack do
  system("rmvn dependency:unpack -f #{RedStorm::REDSTORM_HOME}/pom.xml -DoutputDirectory=#{TARGET_DEPENDENCY_UNPACKED_DIR}")
end

task :jar => [:unpack, :clean_jar] do
  ant.jar :destfile => TARGET_CLUSTER_JAR do
    fileset :dir => TARGET_CLASSES_DIR
    fileset :dir => TARGET_DEPENDENCY_UNPACKED_DIR
    fileset :dir => CWD do
      exclude :name => "target/**/*"
    end
    manifest do
      attribute :name => "Main-Class", :value => "redstorm.TopologyLauncher"
    end
  end
  puts("\nRedStorm jar completed. Generated jar file #{TARGET_CLUSTER_JAR}")
end

task :examples do
  if File.identical?(SRC_EXAMPLES, DST_EXAMPLES)
    STDERR.puts("error: cannot copy examples into itself")
    exit(1)
  end
  if File.exist?(DST_EXAMPLES)
    STDERR.puts("error: directory #{DST_EXAMPLES} already exists")
    exit(1)
  end

  puts("copying examples into #{DST_EXAMPLES}")
  system("mkdir #{DST_EXAMPLES}")
  system("cp -r #{SRC_EXAMPLES}/* #{DST_EXAMPLES}")
  puts("\nRedStorm examples completed. All examples copied in #{DST_EXAMPLES}")
end

task :deps do
  system("rmvn dependency:copy-dependencies -f #{RedStorm::REDSTORM_HOME}/pom.xml -DoutputDirectory=#{TARGET_DEPENDENCY_DIR}")
end

task :build => :setup do
  # compile the JRuby proxy classes to Java
  build_jruby("#{JRUBY_SRC_DIR}/proxy")

  # compile the generated Java proxy classes
  build_java_dir("#{TARGET_SRC_DIR}")

  # generate the JRuby topology launcher
  build_jruby("#{JRUBY_SRC_DIR}/topology_launcher.rb")

  # compile the JRuby proxy classes
  build_java_dir("#{JAVA_SRC_DIR}")

  # compile the JRuby proxy classes
  build_java_dir("#{TARGET_SRC_DIR}")
end 

def build_java_dir(source_folder)
  puts("\n--> Compiling Java")
  ant.javac(
    :srcdir => source_folder,
    :destdir => TARGET_CLASSES_DIR,
    :classpathref => 'classpath', 
    :source => "1.6",
    :target => "1.6",
    :debug => "yes",
    :includeantruntime => "no",
    :verbose => false,
    :listfiles => true
  )
end  

def build_jruby(source_path)
  puts("\n--> Compiling JRuby")
  system("cd #{RedStorm::REDSTORM_HOME}; jrubyc -t #{TARGET_SRC_DIR} --verbose --java -c \"#{TARGET_DEPENDENCY_DIR}/storm-0.5.3.jar\" -c \"#{TARGET_CLASSES_DIR}\" #{source_path}")
end
