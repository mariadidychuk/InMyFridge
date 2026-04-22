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

![Fridge Screen](fridge.png)
![Recipes Screen](recipes.png)
![Calendar Screen](calendar.png)
![Bookmarks Screen](bookmarks.png)
