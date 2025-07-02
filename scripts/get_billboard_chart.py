#!/usr/bin/env python3

import sys
import json
import os

# Add the current directory to the Python path so we can import billboard
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

try:
    import billboard
except ImportError as e:
    print(json.dumps({"error": f"Failed to import billboard module: {str(e)}"}))
    sys.exit(1)

def get_year_end_chart(year, chart_name="hot-100"):
    """
    Get the year-end Billboard chart for a specific year.
    
    Args:
        year (int): The year to fetch
        chart_name (str): The chart name (default: hot-100)
    
    Returns:
        dict: JSON-serializable dictionary with chart data
    """
    try:
        # Fetch the year-end chart
        chart = billboard.ChartData(chart_name, year=str(year))
        
        # Convert chart entries to dictionaries
        entries = []
        for entry in chart.entries:
            entry_dict = {
                "title": entry.title,
                "artist": entry.artist,
                "rank": entry.rank,
                "image": entry.image
            }
            entries.append(entry_dict)
        
        result = {
            "success": True,
            "chart_name": chart.name,
            "year": year,
            "title": chart.title,
            "entries": entries,
            "entry_count": len(entries)
        }
        
        return result
        
    except billboard.BillboardNotFoundException as e:
        return {
            "success": False,
            "error": f"Chart not found: {str(e)}",
            "year": year,
            "chart_name": chart_name
        }
    except billboard.BillboardParseException as e:
        return {
            "success": False,
            "error": f"Failed to parse chart data: {str(e)}",
            "year": year,
            "chart_name": chart_name
        }
    except ValueError as e:
        # Handle the "min() iterable argument is empty" error
        if "min() iterable argument is empty" in str(e):
            return {
                "success": False,
                "error": f"Year {year} not supported for year-end charts",
                "year": year,
                "chart_name": chart_name
            }
        else:
            return {
                "success": False,
                "error": f"Value error: {str(e)}",
                "year": year,
                "chart_name": chart_name
            }
    except Exception as e:
        return {
            "success": False,
            "error": f"Unexpected error: {str(e)}",
            "year": year,
            "chart_name": chart_name
        }

def get_weekly_chart(year, chart_name="hot-100"):
    """
    Get a weekly Billboard chart for a specific year (using January 1st).
    
    Args:
        year (int): The year to fetch
        chart_name (str): The chart name (default: hot-100)
    
    Returns:
        dict: JSON-serializable dictionary with chart data
    """
    try:
        # Try to get a weekly chart from January 1st of the year
        date_str = f"{year}-01-01"
        chart = billboard.ChartData(chart_name, date=date_str)
        
        # Convert chart entries to dictionaries
        entries = []
        for entry in chart.entries:
            entry_dict = {
                "title": entry.title,
                "artist": entry.artist,
                "rank": entry.rank,
                "image": entry.image
            }
            entries.append(entry_dict)
        
        result = {
            "success": True,
            "chart_name": chart.name,
            "year": year,
            "date": date_str,
            "title": chart.title,
            "entries": entries,
            "entry_count": len(entries)
        }
        
        return result
        
    except Exception as e:
        return {
            "success": False,
            "error": f"Failed to get weekly chart: {str(e)}",
            "year": year,
            "chart_name": chart_name
        }

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(json.dumps({"error": "Usage: python get_billboard_chart.py <year> [chart_name]"}))
        sys.exit(1)
    
    try:
        year = int(sys.argv[1])
        chart_name = sys.argv[2] if len(sys.argv) > 2 else "hot-100"
        
        # First try year-end chart
        result = get_year_end_chart(year, chart_name)
        
        # If year-end chart fails, try weekly chart
        if not result['success']:
            result = get_weekly_chart(year, chart_name)
        
        print(json.dumps(result, indent=2))
        
    except ValueError:
        print(json.dumps({"error": "Year must be a valid integer"}))
        sys.exit(1)
    except Exception as e:
        print(json.dumps({"error": f"Unexpected error: {str(e)}"}))
        sys.exit(1) 