Feature: Market Place Catalogs
As a researcher, I want to be able to browse different market place catalogs.

  Background:
    Given I'm signed in as a researcher
    And I have Two Sigma catalog
    And I have Quandl catalog

  Scenario: Default catalog
    Given index "catalog_0.1" has the following market items:
      | title                  | vendor           | format  | tags         | categories |
      | Credit Card Complaints | Bank of America  | json    | bank,america | Two Sigma  |
    When I view the market search
    Then I should see the following filters:
    | filter | values          |
    | vendor | Bank of America |
    | format | json            |
    | tags   | america,bank    |
    And I should see 1 market item on the market list page

  Scenario: Browse different catalogs
    Given index "catalog_0.1" has the following market items:
      | title                  | vendor           | format  | tags         | categories |
      | Credit Card Complaints | Bank of America  | json    | bank,america | Two Sigma  |
    Given index "catalog_0.2" has the following market items:
      | name           | company          | type | categories |
      | Crime in Canada | World Stats Inc. | xml  | Quandl     |
    When I view the market search
    And I browse "Quandl" catalog
    Then I should see the following filters:
    | filter  | values           |
    | company | World Stats Inc. |
    | type    | xml              |
    And I should see 1 market item on the market list page

  Scenario: Search an alternate catalog
    And index "catalog_0.2" has the following market items:
      | name                   | company          | type | categories |
      | Crime in Canada        | World Stats Inc. | xml  | Quandl     |
      | Credit Card Complaints | Bank of America. | json | Quandl     |
    And index "catalog_0.1" has the following market items:
      | title               | company    | type | categories |
      | Zebras in Captivity | Stats Inc. | xml  | Two Sigma  |
    When I view the market search
    And I browse "Quandl" catalog
    And I search the top-level marketplace for "Cri"
    Then I should see 1 market item on the market list page
    When I search the top-level marketplace for "Zebras"
    Then I should see 0 market items on the market list page

  Scenario: Opening last visited catalog
    When I view the market search
    And I browse "Quandl" catalog
    And I view the market search
    Then I should be in "Quandl" catalog

  Scenario: Not showing fields not defined for the catalog
    Given index "catalog_0.2" has the following market items:
      | name            | categories |
      | Crime in Canada | Quandl     |
    When I view the market search
    And I browse "Quandl" catalog
    Then I shouldn't see "Format" field listed on the market list page

  Scenario: Two catalogs with the same path
    And I have a catalog with a duplicate path
    And I view the market search
    And I browse "Duplicate Path" catalog
    And I view the market search
    Then I should be in "Duplicate Path" catalog

