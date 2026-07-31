#!/usr/bin/env ruby

require "fileutils"
require "xcodeproj"

ROOT = File.expand_path("..", __dir__)
PROJECT_PATH = File.join(ROOT, "Observatory.xcodeproj")

FileUtils.rm_rf(PROJECT_PATH)
project = Xcodeproj::Project.new(PROJECT_PATH)
project.root_object.attributes["LastSwiftUpdateCheck"] = "1620"
project.root_object.attributes["LastUpgradeCheck"] = "1620"

domain = project.new_target(:static_library, "ObservatoryDomain", :osx, "14.0")
persistence = project.new_target(:static_library, "ObservatoryPersistence", :osx, "14.0")
app = project.new_target(:application, "Observatory", :osx, "14.0")
tests = project.new_target(:unit_test_bundle, "ObservatoryTests", :osx, "14.0")

def configure_target(target, bundle_identifier)
  target.build_configurations.each do |configuration|
    settings = configuration.build_settings
    settings["SWIFT_VERSION"] = "6.0"
    settings["MACOSX_DEPLOYMENT_TARGET"] = "14.0"
    settings["PRODUCT_BUNDLE_IDENTIFIER"] = bundle_identifier
    settings["GENERATE_INFOPLIST_FILE"] = "YES"
    settings["CODE_SIGN_STYLE"] = "Automatic"
    settings["CODE_SIGN_IDENTITY"] = "-"
    settings["CLANG_ENABLE_MODULES"] = "YES"
    settings["ENABLE_USER_SCRIPT_SANDBOXING"] = "YES"
  end
end

configure_target(domain, "com.iggysleepy.observatory.domain")
configure_target(persistence, "com.iggysleepy.observatory.persistence")
configure_target(app, "com.iggysleepy.observatory")
configure_target(tests, "com.iggysleepy.observatory.tests")

app.build_configurations.each do |configuration|
  settings = configuration.build_settings
  settings.delete("ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME")
  settings["ASSETCATALOG_COMPILER_APPICON_NAME"] = "observatory_icon"
  settings["PRODUCT_NAME"] = "Observatory"
  settings["MARKETING_VERSION"] = "0.1.0"
  settings["CURRENT_PROJECT_VERSION"] = "1"
  settings["INFOPLIST_KEY_CFBundleDisplayName"] = "Observatory"
  settings["INFOPLIST_KEY_LSApplicationCategoryType"] = "public.app-category.utilities"
  settings["ENABLE_APP_SANDBOX"] = "NO"
end

tests.build_configurations.each do |configuration|
  configuration.build_settings["TEST_HOST"] = ""
  configuration.build_settings["BUNDLE_LOADER"] = ""
end

def add_sources(project, target, group_name, relative_directory)
  group = project.main_group.new_group(group_name, relative_directory)
  paths = Dir.glob(File.join(ROOT, relative_directory, "**", "*.swift")).sort
  references = paths.map do |path|
    group.new_file(path.delete_prefix("#{File.join(ROOT, relative_directory)}/"))
  end
  target.add_file_references(references)
  group
end

add_sources(project, domain, "ObservatoryDomain", "ObservatoryDomain")
add_sources(project, persistence, "ObservatoryPersistence", "ObservatoryPersistence")
app_group = add_sources(project, app, "ObservatoryApp", "ObservatoryApp")
add_sources(project, tests, "ObservatoryTests", "ObservatoryTests")

app_icon_group = app_group.new_group("IconSource", "IconSource")
app_icon = app_icon_group.new_file("observatory_icon.icon")
app_icon.last_known_file_type = "folder.iconcomposer.icon"
app.resources_build_phase.add_file_reference(app_icon)

persistence.add_dependency(domain)
app.add_dependency(domain)
app.add_dependency(persistence)
tests.add_dependency(domain)
tests.add_dependency(persistence)
app.frameworks_build_phase.add_file_reference(domain.product_reference)
app.frameworks_build_phase.add_file_reference(persistence.product_reference)
tests.frameworks_build_phase.add_file_reference(domain.product_reference)
tests.frameworks_build_phase.add_file_reference(persistence.product_reference)

package = project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
package.repositoryURL = "https://github.com/groue/GRDB.swift.git"
package.requirement = {
  "kind" => "exactVersion",
  "version" => "7.8.0"
}
project.root_object.package_references << package

def add_package_product(project, target, package, product_name)
  dependency = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  dependency.package = package
  dependency.product_name = product_name
  target.package_product_dependencies << dependency
end

add_package_product(project, persistence, package, "GRDB")
add_package_product(project, app, package, "GRDB")
add_package_product(project, tests, package, "GRDB")

scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(app)
scheme.add_build_target(domain)
scheme.add_build_target(persistence)
scheme.add_test_target(tests)
scheme.set_launch_target(app)
scheme.save_as(PROJECT_PATH, "Observatory", true)

project.save
