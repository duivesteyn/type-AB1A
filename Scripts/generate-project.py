#!/usr/bin/env python3
"""Generate a dependency-free Xcode project with an embedded WidgetKit extension."""
from pathlib import Path
import hashlib, shutil
root = Path(__file__).resolve().parent.parent
objects = {}
def uid(name): return hashlib.sha1(name.encode()).hexdigest()[:24].upper()
def obj(name, value):
    key = uid(name); objects[key] = value; return key
def arr(items): return '(' + ', '.join(items) + ', )' if items else '()'
shared = sorted(root.glob('Sources/Shared/*.swift'))
app = sorted(root.glob('Sources/App/*.swift'))
widget = sorted(root.glob('Sources/Widget/*.swift'))
refs = {}
for p in shared + app + widget:
    rel = p.relative_to(root).as_posix()
    refs[rel] = obj('ref'+rel, f'{{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{rel}"; sourceTree = SOURCE_ROOT; }}')
resources = obj('artwork', '{isa = PBXFileReference; lastKnownFileType = folder; path = Resources/Artwork; sourceTree = SOURCE_ROOT; }')
icon = obj('icon', '{isa = PBXFileReference; lastKnownFileType = image.icns; path = Resources/Clock.icns; sourceTree = SOURCE_ROOT; }')
html = obj('html', '{isa = PBXFileReference; lastKnownFileType = text.html; path = "art/Clock-Live-Preview.html"; sourceTree = SOURCE_ROOT; }')
products = {}
configs = {}
phases = {}
for target, files, product, typ in [('Clock', shared+app, 'Type AB1.app', 'wrapper.application'), ('ClockWidget', shared+widget, 'TypeAB1Widget.appex', 'wrapper.app-extension')]:
    products[target] = obj('product'+target, f'{{isa = PBXFileReference; explicitFileType = "{typ}"; path = "{product}"; sourceTree = BUILT_PRODUCTS_DIR; }}')
    buildfiles = []
    for p in files:
        rel = p.relative_to(root).as_posix()
        buildfiles.append(obj('build'+target+rel, f'{{isa = PBXBuildFile; fileRef = {refs[rel]}; }}'))
    src = obj('sources'+target, f'{{isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = {arr(buildfiles)}; runOnlyForDeploymentPostprocessing = 0; }}')
    resourceFiles = [obj('resource'+target, f'{{isa = PBXBuildFile; fileRef = {resources}; }}')]
    if target == 'Clock':
        resourceFiles += [obj('iconbuild', f'{{isa = PBXBuildFile; fileRef = {icon}; }}'), obj('htmlbuild', f'{{isa = PBXBuildFile; fileRef = {html}; }}')]
    res = obj('resources'+target, f'{{isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = {arr(resourceFiles)}; runOnlyForDeploymentPostprocessing = 0; }}')
    fw = obj('frameworks'+target, '{isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; }')
    phases[target] = [src, fw, res]
    cfgs = []
    for mode in ['Debug', 'Release']:
        settings = {
            'PRODUCT_NAME': 'Type AB1' if target == 'Clock' else 'TypeAB1Widget', 'EXECUTABLE_NAME': 'TypeAB1' if target == 'Clock' else 'TypeAB1Widget', 'PRODUCT_BUNDLE_IDENTIFIER': 'com.duivesteyn.typeab1' + ('.widget' if target != 'Clock' else ''),
            'INFOPLIST_FILE': 'Config/' + ('App' if target == 'Clock' else 'Widget') + '-Info.plist',
            'CODE_SIGN_STYLE': 'Automatic', 'SWIFT_VERSION': '5.0', 'MACOSX_DEPLOYMENT_TARGET': '14.0',
            'GENERATE_INFOPLIST_FILE': 'NO', 'SWIFT_OPTIMIZATION_LEVEL': '-Onone' if mode == 'Debug' else '-O',
            'LD_RUNPATH_SEARCH_PATHS': '$(inherited) @executable_path/../Frameworks',
        }
        if target != 'Clock': settings.update({'APPLICATION_EXTENSION_API_ONLY': 'YES', 'SKIP_INSTALL': 'YES', 'CODE_SIGN_ENTITLEMENTS': 'Config/Widget.entitlements', 'SWIFT_ACTIVE_COMPILATION_CONDITIONS': '$(inherited) CLOCK_APP_INTENTS'})
        pairs = ' '.join(f'{k} = "{v}";' for k,v in settings.items())
        cfgs.append(obj('config'+target+mode, f'{{isa = XCBuildConfiguration; buildSettings = {{{pairs}}}; name = {mode}; }}'))
    configs[target] = obj('configs'+target, f'{{isa = XCConfigurationList; buildConfigurations = {arr(cfgs)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }}')
embedfile = obj('embedfile', f'{{isa = PBXBuildFile; fileRef = {products["ClockWidget"]}; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }}')
embed = obj('embed', f'{{isa = PBXCopyFilesBuildPhase; buildActionMask = 2147483647; dstPath = ""; dstSubfolderSpec = 13; files = ({embedfile}, ); name = "Embed App Extensions"; runOnlyForDeploymentPostprocessing = 0; }}')
phases['Clock'].append(embed)
proxy = obj('proxy', f'{{isa = PBXContainerItemProxy; containerPortal = {uid("project")}; proxyType = 1; remoteGlobalIDString = {uid("targetClockWidget")}; remoteInfo = ClockWidget; }}')
dep = obj('dependency', f'{{isa = PBXTargetDependency; target = {uid("targetClockWidget")}; targetProxy = {proxy}; }}')
for target in ['Clock', 'ClockWidget']:
    obj('target'+target, f'{{isa = PBXNativeTarget; buildConfigurationList = {configs[target]}; buildPhases = {arr(phases[target])}; buildRules = (); dependencies = {arr([dep] if target == "Clock" else [])}; name = {target}; productName = {target}; productReference = {products[target]}; productType = "com.apple.product-type.{"application" if target == "Clock" else "app-extension"}"; }}')
productgroup = obj('products', f'{{isa = PBXGroup; children = {arr(list(products.values()))}; name = Products; sourceTree = "<group>"; }}')
main = obj('main', f'{{isa = PBXGroup; children = {arr(list(refs.values())+[resources, icon, html, productgroup])}; sourceTree = "<group>"; }}')
projcfg = []
for mode in ['Debug', 'Release']:
    projcfg.append(obj('projcfg'+mode, f'{{isa = XCBuildConfiguration; buildSettings = {{SDKROOT = macosx; CLANG_ENABLE_MODULES = YES; }}; name = {mode}; }}'))
configlist = obj('projconfigs', f'{{isa = XCConfigurationList; buildConfigurations = {arr(projcfg)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }}')
project = obj('project', f'{{isa = PBXProject; attributes = {{LastUpgradeCheck = 2600; }}; buildConfigurationList = {configlist}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base); mainGroup = {main}; productRefGroup = {productgroup}; projectDirPath = ""; projectRoot = ""; targets = {arr([uid("targetClock"),uid("targetClockWidget")])}; }}')
projectdir = root/'Clock.xcodeproj'; projectdir.mkdir(exist_ok=True)
(projectdir/'project.pbxproj').write_text('// !$*UTF8*$!\n{archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n' + '\n'.join(f'{k} = {v};' for k,v in objects.items()) + f'\n}}; rootObject = {project}; }}\n')
schemes = projectdir/'xcshareddata/xcschemes'; schemes.mkdir(parents=True, exist_ok=True)
(schemes/'Clock.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2600" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid('targetClock')}" BuildableName="Type AB1.app" BlueprintName="Clock" ReferencedContainer="container:Clock.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid('targetClock')}" BuildableName="Type AB1.app" BlueprintName="Clock" ReferencedContainer="container:Clock.xcodeproj"/></BuildableProductRunnable></LaunchAction><ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"/><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>''')
print('Generated Clock.xcodeproj')
