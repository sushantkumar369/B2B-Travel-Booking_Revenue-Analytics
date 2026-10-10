# B2B Travel Booking & Revenue Analytics

## Project Overview

This is an end-to-end Data Analytics portfolio project based on a synthetic B2B travel booking platform.

The objective of the project is to analyze booking growth, revenue performance, profitability, partner performance, cancellations, refunds, and other key business metrics.

The complete workflow covers:

**Raw Data → Data Profiling → Data Cleaning → Analytics Layer → Python EDA → Power BI Dashboard → Business Insights & Recommendations**

---

## Business Problem

The project focuses on answering the following business questions:

- Where is booking and revenue growth coming from?
- Is the growth profitable?
- Which destinations generate the highest business value?
- Which suppliers, hotels, and travel agents perform best?
- What is driving cancellations and refunds?
- Which business areas should management prioritize?

---

## Tools & Technologies

- PostgreSQL
- SQL
- Python
- Pandas
- Jupyter Notebook
- Power BI
- DAX
- Excel

---

## Dataset

The project uses synthetic B2B travel data covering:

- Bookings
- Travel Agents
- Hotels
- Suppliers
- Destinations
- Payments
- Cancellations

The raw bookings dataset contained more than **120,000 records**.

The dataset is synthetic and created for learning and portfolio purposes. It does not contain confidential company information.

---

## Data Quality Challenges

The raw data contained realistic data-quality issues including:

- Duplicate booking records
- Mixed date formats
- Missing supplier IDs
- Invalid room counts
- Invalid stay-night values
- Zero or negative booking values
- Travel dates before booking dates
- Multiple payment transactions per booking
- Orphan cancellation records
- Mixed currencies
- Inconsistent country names

---

## Data Architecture

The project follows a layered analytical architecture:

```text
RAW
  ↓
STAGING
  ↓
CLEAN
  ↓
ANALYTICS
  ↓
PYTHON
  ↓
POWER BI
  ↓
BUSINESS INSIGHTS
