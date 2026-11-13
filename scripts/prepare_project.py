"""Generate the dependency-free Xcode project and example guide pack."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def uid(label):
    return hashlib.sha1(label.encode()).hexdigest()[:24].upper()

objects = {}
def obj(label, **value):
    key = uid(label)
    objects[key] = value
    return key

def openstep(value, depth=0):
    if isinstance(value, dict):
        return '{\n' + ''.join('\t'*(depth+1)+json.dumps(k)+' = '+openstep(v,depth+1)+';\n' for k,v in value.items()) + '\t'*depth+'}'
    if isinstance(value, list):
        return '(\n' + ''.join('\t'*(depth+1)+openstep(v,depth+1)+',\n' for v in value) + '\t'*depth+')'
    return json.dumps(str(value), ensure_ascii=False)

files = ['Domain.swift', 'Store.swift', 'HexaApp.swift', 'GuidesView.swift', 'ToolsView.swift', 'Meta.swift', 'MetaView.swift', 'SourcesView.swift', 'GuidePresentation.swift', 'VisualGuide.swift', 'PatchContext.swift', 'PatchViews.swift', 'DragonFeed.swift', 'UltimateLibrary.swift', 'Tracker.swift', 'PBEGuides.swift', 'MetaObservations.swift', 'UltimatePanels.swift', 'EsportSchedule.swift', 'OPGGTracker.swift', 'OPGGMeta.swift', 'OPGGProgression.swift']
source_refs=[];source_builds=[];resource_refs=[];resource_builds=[]
for filename in files:
    ref=obj(filename,isa='PBXFileReference',lastKnownFileType='sourcecode.swift',path=filename,sourceTree='<group>')
    source_refs.append(ref);source_builds.append(obj(filename+'build',isa='PBXBuildFile',fileRef=ref))
for filename in ['catalogue.json','reference.json','meta.json','live-meta.json','live-reference.json','pbe-reference.json','ultimate-context.json']:
    ref=obj(filename,isa='PBXFileReference',lastKnownFileType='text.json',path=filename,sourceTree='<group>')
    resource_refs.append(ref);resource_builds.append(obj(filename+'build',isa='PBXBuildFile',fileRef=ref))
asset_ref=obj('assets',isa='PBXFileReference',lastKnownFileType='folder.assetcatalog',path='Assets.xcassets',sourceTree='<group>')
resource_builds.append(obj('assets_build',isa='PBXBuildFile',fileRef=asset_ref))
resources=obj('resources',isa='PBXGroup',children=resource_refs,path='Resources',sourceTree='<group>')
app_group=obj('app_group',isa='PBXGroup',children=source_refs+[resources,asset_ref],path='HexaTFT',sourceTree='<group>')
test_ref=obj('test_ref',isa='PBXFileReference',lastKnownFileType='sourcecode.swift',path='HexaTFTTests.swift',sourceTree='<group>')
test_build=obj('test_build',isa='PBXBuildFile',fileRef=test_ref)
test_group=obj('test_group',isa='PBXGroup',children=[test_ref],path='HexaTFTTests',sourceTree='<group>')
app_product=obj('app_product',isa='PBXFileReference',explicitFileType='wrapper.application',includeInIndex=0,path='HexaTFT.app',sourceTree='BUILT_PRODUCTS_DIR')
test_product=obj('test_product',isa='PBXFileReference',explicitFileType='wrapper.cfbundle',includeInIndex=0,path='HexaTFTTests.xctest',sourceTree='BUILT_PRODUCTS_DIR')
products=obj('products',isa='PBXGroup',children=[app_product,test_product],name='Products',sourceTree='<group>')
main_group=obj('main_group',isa='PBXGroup',children=[app_group,test_group,products],sourceTree='<group>')

def phase(name,isa,files):
    return obj(name,isa=isa,buildActionMask=2147483647,files=files,runOnlyForDeploymentPostprocessing=0)
app_phases=[phase('sources','PBXSourcesBuildPhase',source_builds),phase('frameworks','PBXFrameworksBuildPhase',[]),phase('res_build','PBXResourcesBuildPhase',resource_builds)]
test_phases=[phase('test_sources','PBXSourcesBuildPhase',[test_build]),phase('test_frameworks','PBXFrameworksBuildPhase',[]),phase('test_resources','PBXResourcesBuildPhase',[])]

def configs(label,settings):
    refs=[]
    for name in ['Debug','Release']:
        extra={'SWIFT_OPTIMIZATION_LEVEL':'-Onone','ENABLE_TESTABILITY':'YES','SWIFT_ACTIVE_COMPILATION_CONDITIONS':'DEBUG'} if name=='Debug' else {'SWIFT_COMPILATION_MODE':'wholemodule','SWIFT_OPTIMIZATION_LEVEL':'-O'}
        refs.append(obj(label+name,isa='XCBuildConfiguration',buildSettings={**settings,**extra},name=name))
    return obj(label+'configs',isa='XCConfigurationList',buildConfigurations=refs,defaultConfigurationIsVisible=0,defaultConfigurationName='Release')
common={'SDKROOT':'iphoneos','IPHONEOS_DEPLOYMENT_TARGET':'17.0','SWIFT_VERSION':'5.0','CLANG_ENABLE_MODULES':'YES','CLANG_ENABLE_OBJC_ARC':'YES'}
project_configs=configs('project',common)
app_configs=configs('app',{'PRODUCT_NAME':'$(TARGET_NAME)','PRODUCT_BUNDLE_IDENTIFIER':'com.example.HexaTFT','GENERATE_INFOPLIST_FILE':'YES','INFOPLIST_FILE':'HexaTFT/BackgroundInfo.plist','INFOPLIST_KEY_CFBundleDisplayName':'Hexa','INFOPLIST_KEY_LSApplicationCategoryType':'public.app-category.reference','INFOPLIST_KEY_UILaunchScreen_Generation':'YES','INFOPLIST_KEY_UIApplicationSceneManifest_Generation':'YES','INFOPLIST_KEY_UISupportedInterfaceOrientations':'UIInterfaceOrientationPortrait','TARGETED_DEVICE_FAMILY':'1','MARKETING_VERSION':'0.7.4','CURRENT_PROJECT_VERSION':'14','ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon','CODE_SIGN_STYLE':'Automatic','SWIFT_EMIT_LOC_STRINGS':'YES'})
test_configs=configs('tests',{'PRODUCT_NAME':'$(TARGET_NAME)','PRODUCT_BUNDLE_IDENTIFIER':'com.example.HexaTFTTests','GENERATE_INFOPLIST_FILE':'YES','TARGETED_DEVICE_FAMILY':'1','TEST_HOST':'$(BUILT_PRODUCTS_DIR)/HexaTFT.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/HexaTFT','BUNDLE_LOADER':'$(TEST_HOST)','CODE_SIGN_STYLE':'Automatic'})
app=obj('app',isa='PBXNativeTarget',buildConfigurationList=app_configs,buildPhases=app_phases,buildRules=[],dependencies=[],name='HexaTFT',productName='HexaTFT',productReference=app_product,productType='com.apple.product-type.application')
proxy=obj('proxy',isa='PBXContainerItemProxy',containerPortal=uid('project'),proxyType=1,remoteGlobalIDString=app,remoteInfo='HexaTFT')
dependency=obj('dependency',isa='PBXTargetDependency',target=app,targetProxy=proxy)
tests=obj('tests',isa='PBXNativeTarget',buildConfigurationList=test_configs,buildPhases=test_phases,buildRules=[],dependencies=[dependency],name='HexaTFTTests',productName='HexaTFTTests',productReference=test_product,productType='com.apple.product-type.bundle.unit-test')
ui_ref=obj('ui_ref',isa='PBXFileReference',lastKnownFileType='sourcecode.swift',path='HexaTFTUITests.swift',sourceTree='<group>')
ui_build=obj('ui_build',isa='PBXBuildFile',fileRef=ui_ref)
ui_group=obj('ui_group',isa='PBXGroup',children=[ui_ref],path='HexaTFTUITests',sourceTree='<group>')
objects[main_group]['children'].append(ui_group)
ui_product=obj('ui_product',isa='PBXFileReference',explicitFileType='wrapper.cfbundle',includeInIndex=0,path='HexaTFTUITests.xctest',sourceTree='BUILT_PRODUCTS_DIR')
objects[products]['children'].append(ui_product)
ui_configs=configs('ui',{'PRODUCT_NAME':'$(TARGET_NAME)','PRODUCT_BUNDLE_IDENTIFIER':'com.example.HexaTFTUITests','GENERATE_INFOPLIST_FILE':'YES','TARGETED_DEVICE_FAMILY':'1','TEST_TARGET_NAME':'HexaTFT','CODE_SIGN_STYLE':'Automatic'})
ui_phases=[phase('ui_sources','PBXSourcesBuildPhase',[ui_build]),phase('ui_frameworks','PBXFrameworksBuildPhase',[]),phase('ui_resources','PBXResourcesBuildPhase',[])]
ui_tests=obj('ui_tests',isa='PBXNativeTarget',buildConfigurationList=ui_configs,buildPhases=ui_phases,buildRules=[],dependencies=[dependency],name='HexaTFTUITests',productName='HexaTFTUITests',productReference=ui_product,productType='com.apple.product-type.bundle.ui-testing')
project=obj('project',isa='PBXProject',attributes={'BuildIndependentTargetsInParallel':'YES','LastUpgradeCheck':'1600','TargetAttributes':{app:{'CreatedOnToolsVersion':'16.0'},tests:{'CreatedOnToolsVersion':'16.0','TestTargetID':app}}},buildConfigurationList=project_configs,compatibilityVersion='Xcode 14.0',developmentRegion='fr',hasScannedForEncodings=0,knownRegions=['fr','en','Base'],mainGroup=main_group,productRefGroup=products,projectDirPath='',projectRoot='',targets=[app,tests,ui_tests])
path=ROOT/'HexaTFT.xcodeproj/project.pbxproj'
path.write_text('// !$*UTF8*$!\n'+openstep({'archiveVersion':1,'classes':{},'objectVersion':56,'objects':objects,'rootObject':project})+'\n')
scheme=f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{app}" BuildableName="HexaTFT.app" BlueprintName="HexaTFT" ReferencedContainer="container:HexaTFT.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{tests}" BuildableName="HexaTFTTests.xctest" BlueprintName="HexaTFTTests" ReferencedContainer="container:HexaTFT.xcodeproj"/></TestableReference><TestableReference skipped="NO"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ui_tests}" BuildableName="HexaTFTUITests.xctest" BlueprintName="HexaTFTUITests" ReferencedContainer="container:HexaTFT.xcodeproj"/></TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{app}" BuildableName="HexaTFT.app" BlueprintName="HexaTFT" ReferencedContainer="container:HexaTFT.xcodeproj"/></BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" useCustomWorkingDirectory="NO" debugServiceExtension="internal" savedToolIdentifier=""/>
<AnalyzeAction buildConfiguration="Debug"/>
<ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>'''
(ROOT/'HexaTFT.xcodeproj/xcshareddata/xcschemes/HexaTFT.xcscheme').write_text(scheme)
print('Generated Xcode project:',len(objects),'objects')
