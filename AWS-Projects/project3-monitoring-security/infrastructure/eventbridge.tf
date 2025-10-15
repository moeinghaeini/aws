# EventBridge Rule for CloudWatch Alarms
resource "aws_cloudwatch_event_rule" "cloudwatch_alarms" {
  name        = "monitoring-cloudwatch-alarms"
  description = "Capture CloudWatch alarm state changes"

  event_pattern = jsonencode({
    source      = ["aws.cloudwatch"]
    detail-type = ["CloudWatch Alarm State Change"]
    detail = {
      state = {
        value = ["ALARM"]
      }
    }
  })

  tags = {
    Name = "monitoring-cloudwatch-alarms"
    Project = "monitoring-security"
  }
}

# EventBridge Rule for GuardDuty Findings
resource "aws_cloudwatch_event_rule" "guardduty_findings" {
  name        = "monitoring-guardduty-findings"
  description = "Capture GuardDuty findings"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = {
        gte = [4.0]
      }
    }
  })

  tags = {
    Name = "monitoring-guardduty-findings"
    Project = "monitoring-security"
  }
}

# EventBridge Rule for Security Hub Findings
resource "aws_cloudwatch_event_rule" "securityhub_findings" {
  name        = "monitoring-securityhub-findings"
  description = "Capture Security Hub findings"

  event_pattern = jsonencode({
    source      = ["aws.securityhub"]
    detail-type = ["Security Hub Findings - Imported"]
    detail = {
      findings = {
        Severity = {
          Label = ["HIGH", "CRITICAL"]
        }
      }
    }
  })

  tags = {
    Name = "monitoring-securityhub-findings"
    Project = "monitoring-security"
  }
}

# EventBridge Rule for Config Compliance Changes
resource "aws_cloudwatch_event_rule" "config_compliance" {
  name        = "monitoring-config-compliance"
  description = "Capture Config compliance changes"

  event_pattern = jsonencode({
    source      = ["aws.config"]
    detail-type = ["Config Rules Compliance Change"]
    detail = {
      newEvaluationResult = {
        complianceType = ["NON_COMPLIANT"]
      }
    }
  })

  tags = {
    Name = "monitoring-config-compliance"
    Project = "monitoring-security"
  }
}

# EventBridge Rule for EC2 Instance State Changes
resource "aws_cloudwatch_event_rule" "ec2_state_changes" {
  name        = "monitoring-ec2-state-changes"
  description = "Capture EC2 instance state changes"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance State-change Notification"]
    detail = {
      state = ["stopping", "stopped", "terminated"]
    }
  })

  tags = {
    Name = "monitoring-ec2-state-changes"
    Project = "monitoring-security"
  }
}

# EventBridge Targets
resource "aws_cloudwatch_event_target" "auto_remediation_target" {
  rule      = aws_cloudwatch_event_rule.cloudwatch_alarms.name
  target_id = "AutoRemediationTarget"
  arn       = aws_lambda_function.auto_remediation.arn
}

resource "aws_cloudwatch_event_target" "security_response_target" {
  rule      = aws_cloudwatch_event_rule.guardduty_findings.name
  target_id = "SecurityResponseTarget"
  arn       = aws_lambda_function.security_response.arn
}

resource "aws_cloudwatch_event_target" "security_response_target_2" {
  rule      = aws_cloudwatch_event_rule.securityhub_findings.name
  target_id = "SecurityResponseTarget2"
  arn       = aws_lambda_function.security_response.arn
}

resource "aws_cloudwatch_event_target" "compliance_monitor_target" {
  rule      = aws_cloudwatch_event_rule.config_compliance.name
  target_id = "ComplianceMonitorTarget"
  arn       = aws_lambda_function.compliance_monitor.arn
}

# Lambda Permissions for EventBridge
resource "aws_lambda_permission" "allow_eventbridge_auto_remediation" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auto_remediation.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.cloudwatch_alarms.arn
}

resource "aws_lambda_permission" "allow_eventbridge_security_response" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.security_response.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.guardduty_findings.arn
}

resource "aws_lambda_permission" "allow_eventbridge_security_response_2" {
  statement_id  = "AllowExecutionFromEventBridge2"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.security_response.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.securityhub_findings.arn
}

resource "aws_lambda_permission" "allow_eventbridge_compliance_monitor" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.compliance_monitor.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.config_compliance.arn
}
