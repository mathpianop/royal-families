module PeopleHelper
  


  
  def show_attr(attr_string, subject, attribute, options = {})
    # Display content only if subject and its attribute exist
     attr_string if (subject && subject[attribute])
  end

  
  def show_dates_years(person)
    if !person.death_date
      "b. #{person.birth_date.year}"
    else
      "#{person.birth_date.year}-#{person.death_date.year}"
    end
  end

  def spouses_type_name(person)
    person.sex == "F" ? "Husbands" : "Wives"
  end

  def children_of_spouse(spouse, children_pool)
    children_of_spouse = children_pool.select do |child|
      child.father_id == spouse.id || child.mother_id == spouse.id
    end
  end

  def subject_level_people(subject, siblings)
    siblings.to_a.push(subject).sort_by(&:birth_date)
  end

  def children_by_multiple_spouses?(spouses, children)
    spouses_with_children = spouses.select do |spouse| 
      children.any? do |child| 
        child.father_id == spouse.id || child.mother_id == spouse.id
      end
    end 
    spouses_with_children.length > 1
  end

  def children_by_spouse(spouse, children)
    children.select{|child| child.father_id == spouse.id || child.mother_id == spouse.id}
  end

  def children_clarification_needed?(spouse, family)
    family[:spouses].length > 1 && 
    children_of_spouse(spouse, family[:children]).length > 0
  end

  


end
