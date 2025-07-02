## Quick Setup

### 1. Copy Python Files to Rails App
```bash
# Copy these files to your Rails app's lib/ directory:
cp billboard.py /path/to/your/rails/app/lib/
cp requirements.txt /path/to/your/rails/app/lib/
```

### 2. Install Python Dependencies
```bash
cd /path/to/your/rails/app/lib
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### 3. Create Ruby Wrapper
Create `lib/billboard_service.rb` in your Rails app:

```ruby
require 'open3'
require 'json'

class BillboardService
  def initialize
    @python_path = Rails.root.join('lib', 'venv', 'bin', 'python3')
    @script_path = Rails.root.join('lib', 'billboard.py')
  end

  def get_year_end_chart(year, chart_type = 'hot-100-songs')
    python_code = <<~PYTHON
      import sys
      sys.path.append('#{Rails.root.join('lib')}')
      import billboard
      import json
      
      try:
          chart = billboard.ChartData('#{chart_type}', year='#{year}')
          result = {
              'success': True,
              'title': chart.title,
              'year': chart.year,
              'entries': []
          }
          
          for entry in chart:
              result['entries'] << {
                  'rank': entry.rank,
                  'title': entry.title,
                  'artist': entry.artist
              }
          
          print(json.dumps(result))
      except Exception as e:
          print(json.dumps({'success': False, 'error': str(e)}))
    PYTHON

    stdout, stderr, status = Open3.capture3(@python_path.to_s, '-c', python_code)
    
    if status.success?
      JSON.parse(stdout)
    else
      { 'success' => false, 'error' => stderr }
    end
  end
end
```

### 4. Use in Rails Controller
```ruby
# app/controllers/charts_controller.rb
class ChartsController < ApplicationController
  def year_end
    service = BillboardService.new
    @chart_data = service.get_year_end_chart(params[:year])
    
    if @chart_data['success']
      render json: @chart_data
    else
      render json: { error: @chart_data['error'] }, status: :unprocessable_entity
    end
  end
end
```

### 5. Add Route
```ruby
# config/routes.rb
Rails.application.routes.draw do
  get 'charts/year_end/:year', to: 'charts#year_end'
end
```