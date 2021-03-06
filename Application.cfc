<!---/**
*
* This file is part of MuraCAS
*
* Copyright 2021 University of Maine at Fort Kent
* Licensed under the Apache License, Version v2.0
* http://www.apache.org/licenses/LICENSE-2.0
*
*/ --->
component accessors=true output=false {

	property name='$';

	local.pluginPath = GetDirectoryFromPath(GetCurrentTemplatePath());
	local.muraroot = Left(local.pluginPath, Find('plugins', local.pluginPath, 1) - 1);
	if (DirectoryExists(local.muraroot & 'core')) {
		this.muraAppConfigPath = '../../core/appcfc/';
	} else {
		this.muraAppConfigPath = '../../config/';
	}
	include 'plugin/settings.cfm';
	include this.muraAppConfigPath & 'applicationSettings.cfm';
	try {
		include this.muraAppConfigPath & 'mappings.cfm';
		include '../mappings.cfm';
	} catch(any e) {}

	public any function onApplicationStart() {
		if (this.muraAppConfigPath CONTAINS 'core/') {
			include this.muraAppConfigPath & 'onApplicationStart_include.cfm';
		} else {
			include this.muraAppConfigPath & 'appcfc/onApplicationStart_include.cfm';
		}
		return true;
	}

	public any function onRequestStart(required string targetPage) {
		if (this.muraAppConfigPath CONTAINS 'core/') {
			include this.muraAppConfigPath & 'onRequestStart_include.cfm';
		} else {
			include this.muraAppConfigPath & 'appcfc/onRequestStart_include.cfm';
		}

		if ( isRequestExpired() ) {
			onApplicationStart();
			lock scope='session' type='exclusive' timeout=10 {
				setupSession();
			}
		}

		// You may want to change the methods being used to secure the request
		secureRequest();
		return true;
	}

	public void function onRequest(required string targetPage) {
		var $ = get$();
		var pluginConfig = $.getPlugin(variables.settings.pluginName);
		include arguments.targetPage;
	}

	public void function onSessionStart() {
		if (this.muraAppConfigPath CONTAINS 'core/') {
			include this.muraAppConfigPath &'onSessionStart_include.cfm';
		} else {
			include this.muraAppConfigPath &'appcfc/onSessionStart_include.cfm';
		}
		setupSession();
	}

	public void function onSessionEnd() {
		if (this.muraAppConfigPath CONTAINS 'core/') {
			include this.muraAppConfigPath & 'onSessionEnd_include.cfm';
		} else {
			include this.muraAppConfigPath & 'ppcfc/onSessionEnd_include.cfm';
		}
	}


	// ----------------------------------------------------------------------
	// HELPERS

	private struct function get$() {
		if ( !StructKeyExists(arguments, '$') ) {
			var siteid = StructKeyExists(session, 'siteid') ? session.siteid : 'default';

			arguments.$ = StructKeyExists(request, 'murascope')
				? request.murascope
				: StructKeyExists(application, 'serviceFactory')
					? application.serviceFactory.getBean('$').init(siteid)
					: {};
		}

		return arguments.$;
	}

	public any function secureRequest() {
		var $ = get$();
		return !inPluginDirectory() || $.currentUser().isSuperUser()
			? true
			: ( inPluginDirectory() && !StructKeyExists(session, 'siteid') )
				|| ( inPluginDirectory() && !$.getBean('permUtility').getModulePerm($.getPlugin(variables.settings.pluginName).getModuleID(),session.siteid) )
				? goToLogin()
				: true;
	}

	public boolean function inPluginDirectory() {
		var uri = getPageContext().getRequest().getRequestURI();
		return ListFindNoCase(uri, 'plugins', '/') && ListFindNoCase(uri, variables.settings.package,'/');
	}

	private void function goToLogin() {
		var $ = get$();
		location(url='#$.globalConfig('context')#/admin/index.cfm?muraAction=clogin.main&returnURL=#$.globalConfig('context')#/plugins/#$.getPlugin(variables.settings.pluginName).getPackage()#/', addtoken=false);
	}

	private boolean function isRequestExpired() {
		var p = variables.settings.package;
		return variables.settings.reloadApplicationOnEveryRequest
				|| !StructKeyExists(session, p)
				|| !StructKeyExists(application, 'appInitializedTime')
				|| DateCompare(now(), session[p].expires, 's') == 1
				|| DateCompare(application.appInitializedTime, session[p].created, 's') == 1
				|| (StructKeyExists(variables.settings, 'reloadApplicationOnEveryRequest')
				    && variables.settings.reloadApplicationOnEveryRequest);
	}

	private void function setupSession() {
		var p = variables.settings.package;
		StructDelete(session, p);
		// Expires - s:seconds, n:minutes, h:hours, d:days
		session[p] = {
			created = Now()
			, expires = DateAdd('d', 1, Now())
			, sessionid = Hash(CreateUUID())
		};
	}

}
