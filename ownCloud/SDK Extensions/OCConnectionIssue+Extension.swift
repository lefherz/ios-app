//
//  OCConnectionIssue+Extension.swift
//  ownCloud
//
//  Created by Felix Schwarz on 05.05.18.
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

struct DisplayIssues {
	var targetIssue : OCConnectionIssue //!< The issue to send the approve or decline message to
	var displayLevel : OCConnectionIssueLevel //!< The issue level to be used for display
	var displayIssues: [OCConnectionIssue] //!< The selection of issues to be used for display
	var primaryCertificate : OCCertificate? //!< The first certificate found among the issues
}

extension OCConnectionIssue {
	func prepareForDisplay() -> DisplayIssues {
		var displayIssues: [OCConnectionIssue] = []
		var primaryCertificate: OCCertificate? = self.certificate

		switch self.type {
			case .group:
				displayIssues = self.issuesWithLevelGreaterThanOrEqual(to: self.level)

				for issue in self.issues {
					if issue.type == .certificate {
						primaryCertificate = issue.certificate
						break
					}
				}

			case .urlRedirection, .certificate, .error, .multipleChoice:
				displayIssues = [self]
		}

		return DisplayIssues(targetIssue: self, displayLevel: self.level, displayIssues: displayIssues, primaryCertificate: primaryCertificate)
	}
}
