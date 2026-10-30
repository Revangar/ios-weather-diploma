#!/usr/bin/env python3
"""Recreate the dependency-free shared Xcode project using Python's standard library."""
from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parents[1]
objects = {}
def uid(name): return hashlib.sha1(name.encode()).hexdigest()[:24].upper()
def add(object_name, isa, **values):
    key = uid(object_name)
    objects[key] = {'isa': isa, **values}
    return key

def serialize(value, depth=0):
    if isinstance(value, dict):
        return '{\n' + ''.join('\t'*(depth+1) + json.dumps(k) + ' = ' + serialize(v, depth+1) + ';\n' for k,v in value.items()) + '\t'*depth + '}'
    if isinstance(value,list): return '(\n' + ''.join('\t'*(depth+1)+serialize(v,depth+1)+',\n' for v in value) + '\t'*depth + ')'
    return json.dumps(str(value), ensure_ascii=False)

product_ids=[]
targets=[]
files=[]
for name, folder, kind in [('WeatherDiploma','WeatherDiploma','application'),('WeatherDiplomaTests','WeatherDiplomaTests','bundle.unit-test'),('WeatherDiplomaUITests','WeatherDiplomaUITests','bundle.ui-testing')]:
    sources=[]
    resources=[]
    for p in sorted((root/folder).rglob('*.swift')):
        rel = str(p.relative_to(root))
        ref=add(rel,'PBXFileReference',lastKnownFileType='sourcecode.swift',path=rel,sourceTree='SOURCE_ROOT')
        files.append(ref)
        sources.append(add(rel+'-build','PBXBuildFile',fileRef=ref))
    if kind == 'application':
        for rel,ft in [('WeatherDiploma/Resources/Fixtures/forecast-fixture.json','text.json'),('WeatherDiploma/Resources/PrivacyInfo.xcprivacy','text.xml'),('WeatherDiploma/Resources/Assets.xcassets','folder.assetcatalog')]:
            ref=add(rel,'PBXFileReference',lastKnownFileType=ft,path=rel,sourceTree='SOURCE_ROOT')
            files.append(ref)
            resources.append(add(rel+'-build','PBXBuildFile',fileRef=ref))
        child=add('model-version','PBXFileReference',lastKnownFileType='wrapper.xcdatamodel',path='WeatherModel.xcdatamodel',sourceTree='<group>')
        model=add('model','XCVersionGroup',children=[child],currentVersion=child,path='WeatherDiploma/Resources/WeatherModel.xcdatamodeld',sourceTree='SOURCE_ROOT',versionGroupType='wrapper.xcdatamodel')
        files.append(model)
        resources.append(add('model-build','PBXBuildFile',fileRef=model))
    source_phase=add(name+'-sources','PBXSourcesBuildPhase',buildActionMask='2147483647',files=sources,runOnlyForDeploymentPostprocessing='0')
    resource_phase=add(name+'-resources','PBXResourcesBuildPhase',buildActionMask='2147483647',files=resources,runOnlyForDeploymentPostprocessing='0')
    framework_phase=add(name+'-frameworks','PBXFrameworksBuildPhase',buildActionMask='2147483647',files=[],runOnlyForDeploymentPostprocessing='0')
    product=add(name+'-product','PBXFileReference',explicitFileType='wrapper.application' if kind=='application' else 'wrapper.cfbundle',includeInIndex='0',path=name+('.app' if kind=='application' else '.xctest'),sourceTree='BUILT_PRODUCTS_DIR')
    product_ids.append(product)
    configs=[]
    for config in ['Debug','Release']:
        settings={'PRODUCT_NAME':'$(TARGET_NAME)','PRODUCT_BUNDLE_IDENTIFIER':'com.revangar.'+name,'GENERATE_INFOPLIST_FILE':'YES','CODE_SIGN_STYLE':'Automatic','TARGETED_DEVICE_FAMILY':'1,2','SWIFT_VERSION':'6.0','SWIFT_STRICT_CONCURRENCY':'complete','IPHONEOS_DEPLOYMENT_TARGET':'17.0','SDKROOT':'iphoneos','SWIFT_ACTIVE_COMPILATION_CONDITIONS':'DEBUG' if config=='Debug' else '', 'SWIFT_OPTIMIZATION_LEVEL':'-Onone' if config=='Debug' else '-O','ENABLE_TESTABILITY':'YES' if config=='Debug' else 'NO'}
        if kind=='application': settings.update({'INFOPLIST_FILE':'WeatherDiploma/Resources/Info.plist','GENERATE_INFOPLIST_FILE':'NO','ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon','CURRENT_PROJECT_VERSION':'1','MARKETING_VERSION':'1.0','SUPPORTED_PLATFORMS':'iphoneos iphonesimulator','SUPPORTS_MACCATALYST':'NO'})
        elif kind=='bundle.unit-test': settings.update({'TEST_HOST':'$(BUILT_PRODUCTS_DIR)/WeatherDiploma.app/WeatherDiploma','BUNDLE_LOADER':'$(TEST_HOST)'})
        else: settings.update({'TEST_TARGET_NAME':'WeatherDiploma'})
        configs.append(add(name+config,'XCBuildConfiguration',buildSettings=settings,name=config))
    conf_list=add(name+'-configs','XCConfigurationList',buildConfigurations=configs,defaultConfigurationIsVisible='0',defaultConfigurationName='Release')
    dependencies=[]
    if kind!='application':
        proxy=add(name+'-proxy','PBXContainerItemProxy',containerPortal=uid('project'),proxyType='1',remoteGlobalIDString=uid('WeatherDiploma-target'),remoteInfo='WeatherDiploma')
        dependencies=[add(name+'-dependency','PBXTargetDependency',target=uid('WeatherDiploma-target'),targetProxy=proxy)]
    targets.append(add(name+'-target','PBXNativeTarget',buildConfigurationList=conf_list,buildPhases=[source_phase,framework_phase,resource_phase],buildRules=[],dependencies=dependencies,name=name,productName=name,productReference=product,productType='com.apple.product-type.'+kind))
products=add('products','PBXGroup',children=product_ids,name='Products',sourceTree='<group>')
group=add('main-group','PBXGroup',children=files+[products],sourceTree='<group>')
configs=[]
for config in ['Debug','Release']:
    configs.append(add('project'+config,'XCBuildConfiguration',name=config,buildSettings={'CLANG_ENABLE_MODULES':'YES','CLANG_ENABLE_OBJC_ARC':'YES','GCC_C_LANGUAGE_STANDARD':'gnu17','ALWAYS_SEARCH_USER_PATHS':'NO','DEBUG_INFORMATION_FORMAT':'dwarf' if config=='Debug' else 'dwarf-with-dsym','GCC_PREPROCESSOR_DEFINITIONS':['DEBUG=1','$(inherited)'] if config=='Debug' else ['$(inherited)'],'SWIFT_VERSION':'6.0','IPHONEOS_DEPLOYMENT_TARGET':'17.0','SDKROOT':'iphoneos','ENABLE_USER_SCRIPT_SANDBOXING':'YES'}))
config_list=add('project-configs','XCConfigurationList',buildConfigurations=configs,defaultConfigurationIsVisible='0',defaultConfigurationName='Release')
project=add('project','PBXProject',attributes={'BuildIndependentTargetsInParallel':'YES','LastUpgradeCheck':'2660','TargetAttributes':{uid('WeatherDiplomaTests-target'):{'TestTargetID':uid('WeatherDiploma-target')},uid('WeatherDiplomaUITests-target'):{'TestTargetID':uid('WeatherDiploma-target')}}},buildConfigurationList=config_list,compatibilityVersion='Xcode 14.0',developmentRegion='ru',hasScannedForEncodings='0',knownRegions=['ru','en','Base'],mainGroup=group,productRefGroup=products,projectDirPath='',projectRoot='',targets=targets)
project_dir=root/'WeatherDiploma.xcodeproj'
project_dir.mkdir(exist_ok=True)
(project_dir/'project.pbxproj').write_text('// !$*UTF8*$!\n'+serialize({'archiveVersion':'1','classes':{},'objectVersion':'56','objects':objects,'rootObject':project})+'\n')
schemes=project_dir/'xcshareddata/xcschemes'
schemes.mkdir(parents=True,exist_ok=True)
def ref(name): return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid(name+"-target")}" BuildableName="{name+(".app" if name=="WeatherDiploma" else ".xctest")}" BlueprintName="{name}" ReferencedContainer="container:WeatherDiploma.xcodeproj"/>'
(schemes/'WeatherDiploma.xcscheme').write_text('''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2660" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
<BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">'''+ref('WeatherDiploma')+'''</BuildActionEntry>
</BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables>'''+''.join('<TestableReference skipped="NO" parallelizable="NO">'+ref(n)+'</TestableReference>' for n in ['WeatherDiplomaTests','WeatherDiplomaUITests'])+'''</Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">'''+ref('WeatherDiploma')+'''</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">'''+ref('WeatherDiploma')+'''</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
''')
print(project_dir)
