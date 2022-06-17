/*
 * generated by Xtext 2.24.0
 */
package org.big.erd.validation

import org.big.erd.entityRelationship.Model
import org.big.erd.entityRelationship.NotationType
import org.big.erd.entityRelationship.EntityRelationshipPackage
import com.google.common.collect.Multimaps
import org.eclipse.xtext.validation.Check
import org.big.erd.entityRelationship.AttributeType
import org.apache.log4j.Logger
import org.big.erd.entityRelationship.CardinalityType
import org.big.erd.entityRelationship.RelationEntity
import org.big.erd.entityRelationship.Relationship
import org.eclipse.emf.ecore.EStructuralFeature
import org.big.erd.entityRelationship.Attribute
import org.big.erd.entityRelationship.Entity

/**
 * This class contains custom validation rules. 
 *
 * See https://www.eclipse.org/Xtext/documentation/303_runtime_concepts.html#validation
 */
class EntityRelationshipValidator extends AbstractEntityRelationshipValidator {

	public static String MISSING_MODEL_HEADER = "missingModelHeader";
	public static String MISSING_ATTRIBUTE_DATATYPE = "missingAttributeDatatype";
	public static String LOWERCASE_ENTITY_NAME = "lowercaseEntityName";
	
	@Check
	def checkModel(Model model) {
		if (model.name === null || model.name.isBlank) {
			error('''Missing model header 'erdiagram <name>' ''' , model, EntityRelationshipPackage.Literals.MODEL__NAME,  MISSING_MODEL_HEADER)
		}
	}
	
	@Check
	def checkUppercaseName(Entity entity) {
		if (!Character.isUpperCase(entity.name.charAt(0))) {
			info('''Entity name '«entity.name»' should start with an upper-case letter''', EntityRelationshipPackage.Literals.ENTITY__NAME, LOWERCASE_ENTITY_NAME)
		}
	}
	
	@Check
	def checkAttribute(Attribute attribute) {
		val model = attribute.eContainer.eContainer as Model
		if (model.generateOption !== null && model.generateOption.generateOptionType.toString === 'sql') {
			if (attribute.datatype === null || attribute.datatype.toString.nullOrEmpty) {
				warning('''Missing datatype for attribute''', EntityRelationshipPackage.Literals.ATTRIBUTE__DATATYPE, MISSING_ATTRIBUTE_DATATYPE)
			}
		}
	}
	
	// Names are unique for entities and relationships
    @Check
	def uniqueNames(Model model) {
        // Entities
        val entityNames = Multimaps.index(model.entities, [name ?: ''])
        entityNames.keySet.forEach [ name |
        	val commonName = entityNames.get(name)
			if (commonName.size > 1) 
				commonName.forEach [
					error('''Multiple entites named '«name»'«».''', it, EntityRelationshipPackage.Literals.ENTITY__NAME)
			]
		]
		// Relationships
		val relNames = Multimaps.index(model.relationships, [name ?: ''])
        relNames.keySet.forEach [ name |
			val commonName = relNames.get(name)
			if (commonName.size > 1) 
				commonName.forEach [
					error('''Multiple relationships named '«name»'«».''', it, EntityRelationshipPackage.Literals.RELATIONSHIP__NAME)
			]
		]
    }
    
    @Check
	def extendedEntites(Model model) {
        // Entities
        val extends = model.entities.filter[it.extends !== null]
        if (model.generateOption.generateOptionType.toString === 'sql') {
        	extends.forEach[ e |
        		error('''Code Generator does not support Generalization. Remove extension from '«e.name»'.''', e, EntityRelationshipPackage.Literals.ENTITY__NAME)
        	]
        	
        	
        }
    }
    
    
	// Check if strong entities contain primary key and no partial key
	@Check
	def containsKey(Model model) {
		val entities = model.entities?.filter[e | !e.weak]
        entities.forEach [ e |
			val attributes = e.attributes?.filter[a | a.type === AttributeType.KEY]
			if (attributes.isNullOrEmpty) 
				info('''Missing primary key for entity''', e, EntityRelationshipPackage.Literals.ENTITY__NAME)
		]
    }

	// Check if weak entities contain partial key and no primary key
	@Check
	def containsPartialKey(Model model) {
		val entities = model.entities?.filter[e | e.weak]
        entities.forEach [ e |
			val attributes = e.attributes?.filter[a | a.type == AttributeType.PARTIAL_KEY]
			if (attributes.isNullOrEmpty) 
				info('''Missing partial-key for weak entity''', e, EntityRelationshipPackage.Literals.ENTITY__NAME)
		]
    }
    
  @Check
	def checkCardinality(Model model) {
		
		model.relationships.forEach [ r |
			val firstElement = r.first
			val secondElement = r.second
			val thirdElement = r.third
			
			if(model.notation.notationType.equals(NotationType.BACHMAN)){
				checkBachmanCardinality(firstElement, r, EntityRelationshipPackage.Literals.RELATIONSHIP__FIRST)
				checkBachmanCardinality(secondElement, r, EntityRelationshipPackage.Literals.RELATIONSHIP__SECOND)
				checkBachmanCardinality(thirdElement, r, EntityRelationshipPackage.Literals.RELATIONSHIP__THIRD)
				
			}else if(model.notation.notationType.equals(NotationType.CHEN)){
				checkChenCardinality(firstElement, r, EntityRelationshipPackage.Literals.RELATIONSHIP__FIRST)
				checkChenCardinality(secondElement, r, EntityRelationshipPackage.Literals.RELATIONSHIP__SECOND)
				checkChenCardinality(thirdElement, r, EntityRelationshipPackage.Literals.RELATIONSHIP__THIRD)
				
			}else if(model.notation.notationType.equals(NotationType.CROWSFOOT)){
				if(secondElement === null){
					info('''Relationship: Second element of relation required.''', r, EntityRelationshipPackage.Literals.RELATIONSHIP__FIRST)
				} else if(thirdElement !== null){
					info('''Relationship: No third element allowed.''', r, EntityRelationshipPackage.Literals.RELATIONSHIP__THIRD)
				}else{
					checkCrowsFootCardinality(firstElement, r, EntityRelationshipPackage.Literals.RELATIONSHIP__FIRST)
					checkCrowsFootCardinality(secondElement, r, EntityRelationshipPackage.Literals.RELATIONSHIP__SECOND)
				}
			}else if(model.notation.notationType.equals(NotationType.MINMAX)){
				checkMinMaxCardinality(firstElement, r, EntityRelationshipPackage.Literals.RELATIONSHIP__FIRST)
				checkMinMaxCardinality(secondElement, r, EntityRelationshipPackage.Literals.RELATIONSHIP__SECOND)
				checkMinMaxCardinality(thirdElement, r, EntityRelationshipPackage.Literals.RELATIONSHIP__THIRD)
				
			}else if(model.notation.notationType.equals(NotationType.UML)){
				checkUmlCardinality(firstElement, r, EntityRelationshipPackage.Literals.RELATIONSHIP__FIRST)
				checkUmlCardinality(secondElement, r, EntityRelationshipPackage.Literals.RELATIONSHIP__SECOND)
				checkUmlCardinality(thirdElement, r, EntityRelationshipPackage.Literals.RELATIONSHIP__THIRD)
				checkNoMultipleAggregation(r)
			}
		]
    }
	
	 def checkBachmanCardinality(RelationEntity relationEntity, Relationship relationship, EStructuralFeature feature) {
		if (relationEntity !== null && (relationEntity.cardinality === null || 
										relationEntity.customMultiplicity !== null ||
			 							relationEntity.minMax !== null || relationEntity.uml !== null ||
			 							relationEntity.cardinality === CardinalityType.MANY ||
			 							relationEntity.cardinality === CardinalityType.MANY_CHEN ||
			 							relationEntity.cardinality === CardinalityType.ZERO_OR_ONE)) {
			info('''Wrong cardinality. Usage: [0],[0+],[1] or [1+]''', relationship, feature)
		}
	}
    
    def checkChenCardinality(RelationEntity relationEntity, Relationship relationship, EStructuralFeature feature){
    	if(relationEntity !== null && (relationEntity.cardinality === null ||
    								   relationEntity.customMultiplicity !== null ||
			 						   relationEntity.minMax !== null || relationEntity.uml !== null ||
    								   relationEntity.cardinality === CardinalityType.ZERO ||
    								   relationEntity.cardinality === CardinalityType.ONE_OR_MORE || 
    								   relationEntity.cardinality === CardinalityType.ZERO_OR_MORE ||
			 						   relationEntity.cardinality === CardinalityType.ZERO_OR_ONE)){
			info('''Wrong cardinality. Usage: [1],[N] or [M]''', relationship, feature)
		}
    }
    
     def checkCrowsFootCardinality(RelationEntity relationEntity, Relationship relationship, EStructuralFeature feature){
    	if(relationEntity !== null && (relationEntity.cardinality === null || 
    								   relationEntity.customMultiplicity !== null || 
    								   relationEntity.minMax !== null ||  relationEntity.uml !== null ||
    								   relationEntity.cardinality === CardinalityType.MANY_CHEN ||
    								   relationEntity.cardinality === CardinalityType.MANY ||
    								   relationEntity.cardinality === CardinalityType.ZERO)){
			info('''Wrong cardinality. Usage: [1],[0+],[1+] or [?]''',relationship, feature)
		}
    }
    
    def checkMinMaxCardinality(RelationEntity relationEntity, Relationship relationship, EStructuralFeature feature) {
		if (relationEntity !== null) {
			if (relationEntity.minMax === null || relationEntity.minMax.length < 3) {
				info('''Wrong cardinality.Usage: [min,max] or [min,*]''', relationship, feature)
			}
			if (relationEntity.minMax.toString.length === 3) {
				var n1 = relationEntity.minMax.toString.substring(0, 1);
				var n2 = relationEntity.minMax.toString.substring(2, 3);

				if (n1.matches("\\d+") && n2.matches("\\d+") && Integer.parseInt(n1) > Integer.parseInt(n2)) {
					info('''Wrong cardinality. Usage: [min,max] min <= max''', relationship, feature)
				}
			}
		}
	}
	
	def checkUmlCardinality(RelationEntity relationEntity, Relationship relationship, EStructuralFeature feature) {
		if (relationEntity !== null) {
			if(relationEntity.customMultiplicity !== null || relationEntity.minMax !== null ||
			  (relationEntity.uml === null && relationEntity.cardinality !== CardinalityType.ZERO && 
			  relationEntity.cardinality !== CardinalityType.ONE)){
				info('''Wrong cardinality.Usage: [num],[min..max] or [min..*]''', relationship, feature)
			}
			if(relationEntity.uml.contains("comp") && relationEntity.uml.contains("agg")){
				info('''Invalid aggregation. Use comp or agg''', relationship, feature)
			}
			if (relationEntity.uml.contains("..")) {
				var cardinality = relationEntity.uml
				
				if(relationEntity.uml.contains(" ")){
					// remove type (agg|comp)
					cardinality = relationEntity.uml.split(" ").get(1)
				}
				var numbers = cardinality.split("\\.\\.")
				if(numbers.length <= 1){
					info('''Wrong cardinality. Usage: [min..max] min <= max''', relationship, feature)
				}
				if(numbers.length === 2){
					if(numbers.get(0).isEmpty || numbers.get(1).isEmpty){
						info('''Wrong cardinality. Usage: [min..max] min <= max''', relationship, feature)
					}
					var n1 = numbers.get(0)
					var n2 = numbers.get(1)
					if (n1.matches("\\d+") && n2.matches("\\d+") && Integer.parseInt(n1) > Integer.parseInt(n2)) {
						info('''Wrong cardinality. Usage: [min..max] min <= max''', relationship, feature)
					}
				}
			}
		}
	}
	
	def checkNoMultipleAggregation(Relationship relationship){
		val firstElement = relationship.first
		val secondElement = relationship.second
		val thirdElement = relationship.third
		var aggregationCounter = 0;
		
		if(firstElement != null){
			if(firstElement.uml.contains("agg") || firstElement.uml.contains("comp")){
				aggregationCounter++;
			}
		}
		if(secondElement != null){
			if(secondElement.uml.contains("agg") || secondElement.uml.contains("comp")){
				aggregationCounter++;
				if(aggregationCounter > 1){
					info('''No multiple aggregation possible.''', relationship, EntityRelationshipPackage.Literals.RELATIONSHIP__SECOND)
				}
			}
		}
		if(thirdElement != null){
			if(thirdElement.uml.contains("agg") || thirdElement.uml.contains("comp")){
				aggregationCounter++;
				if(aggregationCounter > 1){
					info('''No multiple aggregation possible.''', relationship, EntityRelationshipPackage.Literals.RELATIONSHIP__THIRD)
				}
			}
		}
	}
    
    /* 
    @Check
	def checkNoCycleInheritance(Entity entity) {
		// dont check if entity does not extend
		if (entity.extends === null)
			return
		
		val visitedEntities = newHashSet(entity)
		var current = entity.extends
		while (current !== null) {
			if (visitedEntities.contains(current)) {
				error('''Cycle in the inheritance of entity '«current.name»' ''', current, EntityRelationshipPackage.Literals.ENTITY__EXTENDS)
			}
			visitedEntities.add(current)
			current = current.extends
		}
	}
	*/
	
}
