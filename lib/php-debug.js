'use babel'
/** @jsx etch.dom */

import etch from 'etch'
import os from 'os'
import {CompositeDisposable} from 'atom'
import DebugEngine from './engines/dbgp/engine'
import DecoratorService from './services/decorator'
import StatusBarDebugView from './status/debug-view'
import StatusBarConsoleView from './status/console-view'
import DefaultBreakpointsView from './breakpoints/default-breakpoints-view'
import compareVersions from 'compare-versions'

class PHPDebug {
  constructor() {
    this._fullyActivated = false;
  }
  activate(state) {
    this._subscriptions = new CompositeDisposable();
    this._engine = new DebugEngine()
    this.showUpgradeNotice()
    this.requirePackages()
    this._state = this.deserialize(state);
    this.registerSubscriptions();
  }

  registerSubscriptions() {
    this._subscriptions.add(atom.commands.add('atom-workspace', {
      'php-debug:run': (event) => {
        if (this._engine != undefined && this._engine != null) {
          let context = this._engine.tryGetContext()
          if (context != null) {
            context.executeRun();
          }
        }
      }
    }));
    this._subscriptions.add(atom.commands.add('atom-workspace', {
      'php-debug:stepOver': (event) => {
        if (this._engine != undefined && this._engine != null) {
          let context = this._engine.tryGetContext()
          if (context != null) {
            context.executeStepOver();
          }
        }
      }
    }));
    this._subscriptions.add(atom.commands.add('atom-workspace', {
      'php-debug:stepIn': (event) => {
        if (this._engine != undefined && this._engine != null) {
          let context = this._engine.tryGetContext()
          if (context != null) {
            context.executeStepInto();
          }
        }
      }
    }));
    this._subscriptions.add(atom.commands.add('atom-workspace', {
      'php-debug:stepOut': (event) => {
        if (this._engine != undefined && this._engine != null) {
          let context = this._engine.tryGetContext()
          if (context != null) {
            context.executeStepOut();
          }
        }
      }
    }));
  }

  showUpgradeNotice() {
    const showWelcome = atom.config.get('php-debug.showWelcome')
    if (!showWelcome) {
      return
    }
    const notification = atom.notifications.addInfo('php-debug', {
        dismissable: true,
        icon: 'bug',
        detail: 'Welcome to the new PHP-Debug! Check out some of the new Features:\n* Multiple Debugging Sessions\n* Cleaner UI\n* Overlay Debugging Command Bar\n* Tool tips for variables while debugging',
        description: 'Many of your previous settings may have changes or may no longer be available. You will likely need to reconfigure the package.',
        buttons: [{
          text: 'Open Settings Now',
          onDidClick: () => {
            notification.dismiss()
            atom.config.set('php-debug.showWelcome', false)
            this.openSettingsView()
          }
        },{
          text: 'Got It',
          onDidClick: () => {
            notification.dismiss()
            atom.config.set('php-debug.showWelcome', false)
          }
        }, {
          text: 'Remind Me Next Time',
          onDidClick: () => {
            notification.dismiss()
          }
        }]
      })
  }

  openSettingsView() {
    atom.workspace.open('atom://config/packages/php-debug')
  }

  requirePackages() {
    const pkg = 'atom-debug-ui'
    const detail = 'It provides IDE/UI features for debugging inside atom'
    const packages = new Map()
    packages.set("atom-debug-ui",{required:true,details:'It provides IDE/UI features for debugging inside atom'})
    packages.set("ide-php",{required:false,details:'It provides IDE features for PHP'})
    packages.set("atom-ide-ui",{required:false,details:'It provides IDE features for Atom that will be used by ide-php'})
    for (let [pkg, info] of packages) {

      const existingPkg = atom.packages.getLoadedPackage(pkg)
      if (existingPkg != null) {
        continue;
      }

      const preDisabledBundledPackages = atom.config.get('php-debug.noPackageInstallPrompt')
      if (preDisabledBundledPackages.includes(pkg)) {
        continue;
      }

      const notification = atom.notifications.addInfo('php-debug', {
        dismissable: true,
        icon: 'cloud-download',
        detail: 'This package '+ (info.required ? 'requires' : 'works better with') + ' the ' + pkg + ' package. ' + info.details,
        description: 'Would you like to install **' + pkg + '**?' + (info.required ? ' **It is _required_ for this plugin to work.**' : ''),
        buttons: [{
          text: 'Yes',
          onDidClick: () => {
            notification.dismiss()
            this.installPkg(pkg)
          }
        }, {
          text: 'Not Now',
          onDidClick: () => {
            notification.dismiss()
          }
        }, {
          text: 'Never',
          onDidClick: () => {
            notification.dismiss()
            const disabledBundledPackages = atom.config.get('php-debug.noPackageInstallPrompt')
            if (!disabledBundledPackages.includes(pkg)) {
              disabledBundledPackages.push(pkg)
              atom.config.set('php-debug.noPackageInstallPrompt', disabledBundledPackages)
            }
          }
        }]
      })
    }
  }

  showVersionNotice() {
    const notification = atom.notifications.addInfo('php-debug', {
        dismissable: true,
        icon: 'bug',
        detail: 'Please install the latest version of atom-debug-ui and restart Atom.\nPHP-Debug will not work without the latest version',
        description: 'It looks like the version of **atom-debug-ui** you have installed is too old!',
        buttons: [{
          text: 'Okay',
          onDidClick: () => {
            notification.dismiss()
          }
        }]
      })
  }

  installPkg(pkg) {
    console.debug(`Attempting to install installing package ${pkg}`)
    const p = atom.packages.activatePackage('settings-view')
    if (!p) {
      return
    }
    p.then( (settingsPkg) => {
    if (!settingsPkg  || !settingsPkg.mainModule) {
       console.warn("Could not find settings view")
       return
    }
    const settingsview = settingsPkg.mainModule.createSettingsView({uri: settingsPkg.mainModule.configUri})
      settingsview.packageManager.install({name: pkg}, (error) => {
        if (!error) {
          console.info(`The ${pkg} package has been installed`)
          atom.notifications.addInfo(`Installed the ${pkg} package`)
        } else {
          let content = ''
          if (error.stdout) {
            content = error.stdout
          }
          if (error.stderr) {
            content = content + os.EOL + error.stderr
          }
          content = content.trim()
          atom.notifications.addError(content)
          console.error(error)
        }
      })
    }).catch( (err) => {
      console.warn("Could not find settings view package",err)
    })
  }

  provideDebugEngineService() {
    if (this._engine.isDestroyed) {
      this._engine = new DebugEngine()
    }
    return this._engine
  }

  consumeDebugUI(services) {
    try {
      const existingPkg = atom.packages.getLoadedPackage("atom-debug-ui")
      if (existingPkg == null) {
        return
      }
      let debugUiVersion = existingPkg.metadata.version;
      if (compareVersions(debugUiVersion,'1.0.3') < 0) {
        this.showVersionNotice()
        return;
      }
      this._fullyActivated = true;

      if (this._services != undefined || this._services != null) {
        this._services.destroy()
        this._subscriptions.dispose()
        this._subscriptions = new CompositeDisposable()
      }
      this._services = services
      this._engine.setUIServices(services)
      this._services.activate(this._engine.getName(), this._state.services)
      this._subscriptions.add(this._services.onServiceRegistered(this.serviceRegistered.bind(this)))
      this._services.registerService('Decorator',new DecoratorService(this._services,{}))
      this._services.requestService('actions',{},this.actionsServiceActivated.bind(this))
      this._services.requestService('stack')
      this._services.requestService('console')
      this._services.requestService('status')
      this._services.requestService('scope')
      this._services.requestService('watches')
      //xDebug does not support watchpoints
      //this._services.requestService('watchpoints')
      const view = <DefaultBreakpointsView services="{this._services}" />
      const breakpointsOptions = {
        attachedViews: view
      }
      this._services.requestService('breakpoints',breakpointsOptions)
      const viewOptions = {
        allowDefaultConsole: true,
        allowDefaultDebugger: true,
        uriPrefix:'php-debug',
        debugViewTitle:'PHP Debug',
        consoleViewTitle:'PHP Console',
        combineBreakpointsWatchpoints: false
      }
      this._services.requestService('debugview',viewOptions,this.debugViewServiceActivated.bind(this))
      this._services.getLoggerService().info("Received Debug UI Services")
    } catch (err) {
      atom.notifications.addError(`Failed to load PHP-Debug`, {
        detail: err,
        dismissable: true
      })
      throw err
    }
  }

  getGrammarScopes() {
     return ['text.html.php'];
  }

  consumeDatatip(service) {
    let provider = {
      providerName: "PHPDebugLanguageClient",
      priority: 12,
      grammarScopes: this.getGrammarScopes(),
      validForScope: (scopeName) => {
        return this.getGrammarScopes().includes(scopeName)
      },
      datatip: this.getDatatip.bind(this)
    }
    service.addProvider(provider);
  }

  getDatatip(tipEditor, tipPoint) {
    return new Promise((resolve,reject) => {
      if (this._engine == undefined || this._engine == null) {
        reject();
        return;
      }
      let pkg = atom.packages.getActivePackage("ide-php")
      if (pkg == undefined || pkg == null) {
        reject();
        return;
      }
      pkg.mainModule.getDatatip(tipEditor,tipPoint).then((result) => {
        let editor = atom.workspace.getActivePaneItem();
        if (editor == undefined || editor == null || editor.getTextInBufferRange == undefined || result == undefined || result == null) {
          reject();
          return;
        } else {
          let highlight = editor.getTextInBufferRange(result.range);
          let debugContext = this._engine.tryGetContext();
          if (debugContext == undefined || debugContext == null) {
            reject();
            return;
          }
          if (highlight == undefined || highlight == null) {
            reject();
            return;
          } else {
            let p = debugContext.evalExpression(highlight)
            p.then((data) => {
              let markedString = {
                grammar: editor.getGrammar(),
                type: "snippet",
                value: "\"" + data + "\""
              }
              if (result.markedStrings != undefined && result.markedStrings != null) {
                result.markedStrings = [];
                result.markedStrings.push(markedString);
              }
              resolve(result)
              return;
            });
          }
        }
      }).catch((error) => {
        reject(error);
        return;
      });
    });
  }


  debugViewServiceActivated(service,options) {
    this._subscriptions.add(service.onDefaultDebuggerRequested(() => {
      this._engine.createDebuggingContext("default").then( (context) => {
        const uiService = context.getUIService()
        if (uiService != null) {
          uiService.activateDebugger()
        }
      })
    }))
    this._subscriptions.add(service.onDefaultConsoleRequested(() => {
      this._engine.createDebuggingContext("default").then( (context) => {
        const uiService = context.getUIService()
        if (uiService != null) {
          uiService.activateDebugger()
        }
      })
    }))
    this._subscriptions.add(service.onContextCreated(this.debugContextViewServiceCreated.bind(this)))
  }

  actionsServiceActivated(service,options) {
    service.hideActionButtons(['attach','run'])
  }

  debugContextViewServiceCreated(event) {
    event.service.enablePanels(['watches','breakpoints','context','stack'])
  }

  serviceRegistered(event) {
    this._services.getLoggerService().info('Service registered: ' + event.name)
  }

  consumeStatusBar (statusBar) {
    this._subscriptions.add(atom.config.observe("php-debug.display.enableStatusbarButtons", (enable) => {
      if (enable) {
        this._debugView = new StatusBarDebugView({statusBar:statusBar, engine:this._engine})
        this._consoleView = new StatusBarConsoleView({statusBar:statusBar, engine:this._engine})
      }
      else {
        if (this._consoleView != undefined && this._consoleView != null) {
          this._consoleView.destroy()
          delete this._consoleView
        }
        if (this._debugView != undefined && this._debugView != null) {
          this._debugView.destroy()
          delete this._debugView
        }
      }
    }))
  }

  deactivate() {
    if (this._engine != undefined && this._engine != null) {
      this._engine.destroy()
      delete this._services
    }
    if (this._service != undefined && this._engine != null) {
      this._services.destroy()
      delete this._services
    }
    if (this._subscriptions != undefined && this._subscriptions != null) {
      this._subscriptions.dispose()
      delete this._subscriptions
    }
  }


  serialize() {
    if (this._services != undefined && this._services != null) {
      var results = {
        "deserializer": "PHPDebug",
        "data": {
          "services" : this._services.serialize()
        }
      }
      return results;
    }
    if (!this._fullyActivated) {
      return this._state;
    }
    return {};
  }
  deserialize(state) {
    if (state != null) {
      if (typeof state.data === "object") {
        return state.data;
      } else {
        return {"services":null}
      }
    }
  }
}
atom.deserializers.add(PHPDebug);
module.exports = new PHPDebug()
