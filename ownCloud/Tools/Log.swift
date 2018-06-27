//
//  Log.swift
//  ownCloud
//
//  Created by Felix Schwarz on 09.03.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2018, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

import UIKit

import ownCloudSDK

class Log {
	static func debug(_ message: String, _ parameters: CVarArg..., file: String = #file, functionName: String = #function, line: UInt = #line ) {
		withVaList(parameters) { va_list in
			OCLogger.shared.appendLogLevel(OCLogLevel.debug, functionName: functionName, file: file, line: line, message: message, arguments: va_list)
		}
	}

	static func log(_ message: String, _ parameters: CVarArg..., file: String = #file, functionName: String = #function, line: UInt = #line ) {
		withVaList(parameters) { va_list in
			OCLogger.shared.appendLogLevel(OCLogLevel.default, functionName: functionName, file: file, line: line, message: message, arguments: va_list)
		}
	}

	static func warning(_ message: String, _ parameters: CVarArg..., file: String = #file, functionName: String = #function, line: UInt = #line ) {
		withVaList(parameters) { va_list in
			OCLogger.shared.appendLogLevel(OCLogLevel.warning, functionName: functionName, file: file, line: line, message: message, arguments: va_list)
		}
	}

	static func error(_ message: String, _ parameters: CVarArg..., file: String = #file, functionName: String = #function, line: UInt = #line ) {
		withVaList(parameters) { va_list in
			OCLogger.shared.appendLogLevel(OCLogLevel.error, functionName: functionName, file: file, line: line, message: message, arguments: va_list)
		}
	}

	static func mask(_ obj: Any?) -> Any {
		return (OCLogger.shared.applyPrivacyMask(obj))
	}
}
