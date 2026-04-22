# InMyFridge

## Description
InMyFridge is an offline-first mobile application that helps users manage ingredients they already have at home and discover suitable recipes based on those ingredients. The app aims to reduce food waste and simplify everyday meal planning.

## Key Features
- Ingredient management (add, edit, delete)
- Recipe recommendations based on available ingredients
- Filtering and search functionality
- Bookmark (favorites) system
- Calendar-based meal planning
- Fully offline usage with local data storage

## Tech Stack
- Flutter (Dart)
- Hive (NoSQL local database)

## Architecture
The application follows a structured architecture with clear separation of concerns:

- **Data Layer:**  
  Data models such as `Recipe` and `RecipeIngredient`  
- **Persistence Layer:**  
  Local storage using Hive (ingredientsBox, recipesBox, favoritesBox, calendarBox)  
- **Presentation Layer:**  
  Multiple UI screens connected via structured navigation  

The app uses an **offline-first approach**, ensuring full functionality without internet access.

## Core Logic
The application implements a matching algorithm that compares user-available ingredients with stored recipes.

Key aspects:
- Recipes are filtered based on available ingredients
- Results are sorted by number of missing ingredients
- Recipes with the highest match are prioritized
- Basic ingredients (e.g. salt, water) can be ignored in matching logic

## My Contributions
- Designed and implemented the core application structure and navigation (BottomNavigationBar)
- Developed the **Fridge module** for ingredient management (add, edit, delete)
- Built the **Recipes screen** including filtering and search functionality
- Implemented the **ingredient-based recipe matching logic**
- Designed the overall user flow and interaction logic
- Delivered the first fully functional prototype of the application

## Additional Features Implemented in the Project
- Bookmark system for saving favorite recipes
- Calendar-based meal planning with persistent storage
- Reactive UI updates using local data listeners
- JSON-based seed data loading for initial recipes

## Project Context
This project was developed as part of the "Programming 2" module in the Business Informatics program at HSBA.

## Status
Student project / functional prototype

## Screenshots

### Recipes for You
<img width="300" src="https://github.com/user-attachments/assets/a3c07687-b1cc-445c-a3ea-4db006dac5f7" />

### Calendar
<img width="300" src="https://github.com/user-attachments/assets/dfa74756-1aad-4a1c-8b67-037432267668" />

### Bookmarks & Recipe Details
<img width="300" src="https://github.com/user-attachments/assets/9d035f45-4e9a-4fc3-870e-7de327cdbdcc" />

### Fridge & All Recipes
<img width="300" src="https://github.com/user-attachments/assets/8a061af1-10e0-4591-8f3d-4f75fde371f3" />
